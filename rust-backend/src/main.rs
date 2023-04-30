mod game;

use crate::game::Game;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        Query, State,
    },
    http::StatusCode,
    response::{IntoResponse, Redirect, Response},
    routing::{get, MethodFilter},
    Router,
};
use rand::{distributions::Alphanumeric, Rng};
use serde::Deserialize;
use std::collections::HashMap;
use std::fmt::{Display, Formatter};
use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::watch::Receiver;
use tokio::time::{sleep, Duration};
use tower_http::trace::TraceLayer;
use tracing::debug;
use tracing_subscriber;

#[derive(Debug)]
struct AppState {
    pub frontend_url: String,
    pub games: Arc<RwLock<HashMap<String, Arc<Mutex<Game>>>>>,
}

impl Display for AppState {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "AppState(GameCount: {})",
            self.games.read().unwrap().len()
        )
    }
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let frontend_url =
        std::env::var("FRONTEND_URL").unwrap_or_else(|_| "http://localhost:5173/".to_string());
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());

    let shared_state = Arc::new(AppState {
        frontend_url: frontend_url,
        games: Arc::new(RwLock::new(HashMap::new())),
    });

    let app = Router::new()
        .route(
            "/",
            get(redirect_to_frontend).on(MethodFilter::OPTIONS, cors_options),
        )
        .route("/ws", get(open_conn))
        .route("/health", get(|| async { StatusCode::OK }))
        .route("/robots.txt", get(robots_txt))
        .fallback(get(redirect_to_frontend))
        .with_state(shared_state)
        .layer(TraceLayer::new_for_http());

    let addr = format!("0.0.0.0:{}", port);
    println!("Listening on {}, set RUST_LOG=\"info,tictactoe_rs=trace,tower_http=trace\" to see detailed logs.", addr);

    axum::Server::bind(&addr.parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn redirect_to_frontend(State(state): State<Arc<AppState>>) -> Redirect {
    Redirect::temporary(&state.frontend_url.as_str())
}

async fn cors_options(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    (
        StatusCode::NO_CONTENT,
        [
            ("Access-Control-Allow-Origin", state.frontend_url.clone()),
            ("Access-Control-Allow-Methods", String::from("GET, OPTIONS")),
            ("Access-Control-Allow-Headers", String::from("Content-Type")),
            ("Access-Control-Max-Age", String::from("3600")),
        ],
    )
}

async fn robots_txt() -> (StatusCode, &'static str) {
    (StatusCode::OK, "User-agent: *\nDisallow: /\n")
}

#[derive(Debug, Deserialize)]
struct NewGameParams {
    #[serde(default)]
    pub token: Option<String>,
    #[serde(default)]
    pub name: Option<String>,
}

impl NewGameParams {
    pub fn normalized(&self) -> NewGameParams {
        NewGameParams {
            token: self
                .token
                .clone()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty()),
            name: self
                .name
                .clone()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty()),
        }
    }

    pub fn is_valid(&self) -> bool {
        if let Some(token) = &self.token {
            if token.len() > 32 {
                return false;
            }
        }
        return true;
    }
}

async fn open_conn(
    Query(params): Query<NewGameParams>,
    State(state): State<Arc<AppState>>,
    ws: WebSocketUpgrade,
) -> Response {
    let params = params.normalized();
    if !params.is_valid() {
        return (StatusCode::BAD_REQUEST, "Invalid parameters").into_response();
    }

    ws.on_upgrade(|socket| handle_socket(socket, params, state))
}

struct JoinGameResult {
    id: String,
    player: game::Player,
    game_state: game::State,
    receive_from_game: Receiver<game::State>,
}

async fn handle_socket(mut socket: WebSocket, params: NewGameParams, state: Arc<AppState>) {
    // let redis = state.redis_conn_mgr.clone();
    debug!("New WebSocket connection with params: '{:?}'", params);

    let game: Arc<Mutex<Game>> = params
        .token
        .clone()
        .and_then(|token| {
            // if we have a token, try to get the game matching the token
            let games = state.games.read().unwrap();
            games.get(&token).map(|g| g.clone())
        })
        .unwrap_or_else(|| {
            // if after that we still don't have a game, create a new one

            let id: String = params.token.unwrap_or_else(|| random_token());
            // TODO: when generating random token, check for collisions

            let (game, _) = Game::new(id.clone());

            let game = Arc::new(Mutex::new(game));

            state.games.write().unwrap().insert(id, game.clone());
            game
        });

    // now that we got a game, add the connected user as a player,
    // extract some data from it and send state to client
    let join_game_result: Result<JoinGameResult, String> = {
        let mut game = game.lock().unwrap();

        match game.add_player(params.name.unwrap_or_else(|| "Unnamed Player".to_string())) {
            Ok(_player) => {
                game.broadcast_state();

                Ok(JoinGameResult {
                    id: game.id.clone(),
                    player: _player,
                    game_state: game.state.clone(),
                    receive_from_game: game.state_changes.subscribe(),
                })
            }
            Err(e) => Err(e),
        }
    };

    let join_game_result = match join_game_result {
        Ok(j) => j,
        Err(e) => {
            let json = serde_json::to_string(&game::ToBrowser::Error(e)).unwrap();
            socket.send(Message::Text(json)).await.unwrap();
            socket.close().await.unwrap();
            return;
        }
    };

    let player = join_game_result.player;
    let mut receive_from_game = join_game_result.receive_from_game;

    let json = serde_json::to_string(&game::ToBrowser::JoinedGame {
        token: join_game_result.id,
        player_id: player.id,
        state: join_game_result.game_state,
    })
    .unwrap();
    socket.send(Message::Text(json)).await.unwrap();

    let disconnect = || {
        debug!(
            "Socket: Player {:?} disconnected, removing from game",
            player
        );
        let mut game = game.lock().unwrap();
        game.remove_player(player.id);
        if game.state.players.is_empty() {
            debug!("Socket: Game is empty, removing globally");
            state.games.write().unwrap().remove(&game.id);
        }
        game.broadcast_state();
    };

    loop {
        tokio::select! {
            _ = sleep(Duration::from_secs(10)) => {
                debug!("Socket: Ping");
                socket.send(Message::Ping(vec![])).await.unwrap();
            }
            _ = receive_from_game.changed() => {
                let new_state = receive_from_game.borrow().clone();
                // trace!("Socket: Sending game state change: {:?}", new_state);

                let json = serde_json::to_string(&game::ToBrowser::GameState(new_state)).unwrap();
                socket.send(Message::Text(json)).await.unwrap();
            }
            msg = socket.recv() => {
                match msg {
                    Some(raw_msg) => {
                        debug!("Socket: Received message: {:?}", raw_msg);
                        match raw_msg {
                            Ok(Message::Text(json)) => {
                                let parsed: game::FromBrowser = serde_json::from_str(&json).unwrap();
                                debug!("Socket: Parsed message: {:?}", parsed);

                                let server_err = {
                                    let mut game = game.lock().unwrap();
                                    let result = game.handle_msg(player.id, parsed);
                                    match result {
                                        Ok(changed) => {
                                            if changed {
                                                game.broadcast_state();
                                            }
                                            None
                                        }

                                        Err(e) => {
                                            Some(e)
                                        }
                                    }
                                    // lock game
                                };

                                if let Some(e) = server_err {
                                    debug!("Socket: Error handling message: {:?}", e);
                                    let json = serde_json::to_string(&game::ToBrowser::Error(e)).unwrap();
                                    socket.send(Message::Text(json)).await.unwrap();
                                }
                            }

                            Ok(Message::Close(_)) => {
                                debug!("Socket: Client closed connection");
                                disconnect();
                                return;
                            }

                            Ok(Message::Ping(_)) => {
                                debug!("Socket: Client pinged");
                                socket.send(Message::Pong(vec![])).await.unwrap();
                            }

                            Ok(Message::Pong(_)) => {
                                debug!("Socket: Client ponged");
                            }

                            _ => {
                                debug!("Socket: Unhandled message type, ignoring");
                            }
                        }
                    }
                    None => {
                        debug!("Socket: Client disconnected");
                        disconnect();
                        return;
                    }
                }
            }
        }
    }
}

fn random_token() -> String {
    return rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(7)
        .map(char::from)
        .collect();
}
