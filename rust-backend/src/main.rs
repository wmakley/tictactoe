mod game;
mod server;

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
use serde::Deserialize;
use std::sync::Arc;
use tokio::time::{sleep, Duration};
use tower_http::trace::TraceLayer;
use tracing::debug;
use tracing_subscriber;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let frontend_url =
        std::env::var("FRONTEND_URL").unwrap_or_else(|_| "http://localhost:5173/".to_string());
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());

    let shared_state = Arc::new(server::State::new(frontend_url.clone()));

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

async fn redirect_to_frontend(State(state): State<Arc<server::State>>) -> Redirect {
    Redirect::temporary(&state.frontend_url.as_str())
}

async fn cors_options(State(state): State<Arc<server::State>>) -> impl IntoResponse {
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
    State(state): State<Arc<server::State>>,
    ws: WebSocketUpgrade,
) -> Response {
    let params = params.normalized();
    if !params.is_valid() {
        return (StatusCode::BAD_REQUEST, "Invalid parameters").into_response();
    }

    ws.on_upgrade(|socket| handle_socket(socket, params, state))
}

async fn handle_socket(mut socket: WebSocket, params: NewGameParams, state: Arc<server::State>) {
    // let redis = state.redis_conn_mgr.clone();
    debug!("New WebSocket connection with params: '{:?}'", params);

    let mut conn = match server::join_or_new_game(state.clone(), params.token, params.name) {
        Ok(c) => c,
        Err(e) => {
            let json = serde_json::to_string(&game::ToBrowser::Error(e)).unwrap();
            socket.send(Message::Text(json)).await.unwrap();
            socket.close().await.unwrap();
            return;
        }
    };

    let json = serde_json::to_string(&game::ToBrowser::JoinedGame {
        token: conn.game_id.clone(),
        player_id: conn.player.id,
        state: conn.game_state.borrow().clone(),
    })
    .unwrap();
    socket.send(Message::Text(json)).await.unwrap();

    loop {
        tokio::select! {
            _ = sleep(Duration::from_secs(10)) => {
                debug!("Socket: Ping");
                socket.send(Message::Ping(vec![])).await.unwrap();
            }
            _ = conn.game_state.changed() => {
                let new_state = {
                    conn.game_state.borrow().clone()
                    // make sure to release the borrow immediately
                };
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
                                    let mut game = conn.game.lock().unwrap();
                                    let result = game.handle_msg(conn.player.id, parsed);
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
                                    // release lock
                                };

                                if let Some(e) = server_err {
                                    debug!("Socket: Error handling message: {:?}", e);
                                    let json = serde_json::to_string(&game::ToBrowser::Error(e)).unwrap();
                                    socket.send(Message::Text(json)).await.unwrap();
                                }
                            }

                            Ok(Message::Close(_)) => {
                                debug!("Socket: Client closed connection");
                                return;
                            }

                            Ok(Message::Pong(_)) => {}

                            Ok(Message::Ping(_)) => {}

                            Ok(Message::Binary(_)) => {
                                debug!("Socket: Received unexpected binary message, closing connection");
                                return;
                            }

                            Err(e) => {
                                // most errors seem to be resets or disconnects
                                debug!("Socket: Error: {:?}, closing connection", e);
                                return;
                            }
                        }
                    }
                    None => {
                        debug!("Socket: Client disconnected");
                        return;
                    }
                }
            }
        }
    }
}
