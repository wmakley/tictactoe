use async_tungstenite::{
    tokio::{connect_async, TokioAdapter},
    tungstenite::Message,
    WebSocketStream,
};
use clap::Parser;
use futures::prelude::*;
use serde::{Deserialize, Serialize};
use tokio::{
    net::TcpStream,
    sync::oneshot,
    task::JoinSet,
    time::{sleep, Duration},
};

#[derive(Debug, Parser)]
struct Args {
    address: String,
    n: usize,
}

static X_SCRIPT: [usize; 4] = [4, 1, 2, 8];
static O_SCRIPT: [usize; 4] = [0, 7, 6, 3];

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    // println!("Options: {:?}", args);

    // play n games
    let mut set = JoinSet::new();
    for i in 0..args.n {
        set.spawn(play_test_game(i, args.address.clone()));
    }

    let mut times: Vec<Duration> = Vec::with_capacity(args.n);
    while let Some(r) = set.join_next().await {
        match r {
            Ok(Ok(result)) => {
                times.push(result.elapsed_time);
            }
            Ok(Err(e)) => println!("Game ended with error: {}", e),
            Err(e) => println!("Join Error: {:?}", e),
        }
    }

    println!(
        "avg time: {}ms",
        times.iter().sum::<Duration>().as_millis() / times.len() as u128
    );

    Ok(())
}

async fn play_test_game(id: GameID, address: String) -> Result<GameResult, String> {
    let start_time = std::time::Instant::now();

    let mut client1 = spawn_client(
        id,
        1,
        address.to_string(),
        String::from("P1"),
        String::from(""),
        10,
        tokio::time::Duration::from_secs(60),
        &X_SCRIPT,
    )
    .await?;
    // drops conn 1 if connection fails
    let mut client2 = spawn_client(
        id,
        2,
        address.to_string(),
        String::from("P2"),
        client1.join_token.clone(),
        10,
        tokio::time::Duration::from_secs(60),
        &O_SCRIPT,
    )
    .await?;

    let (r1, r2) = futures::join!(client1.finished(), client2.finished());
    if r1.is_err() || r2.is_err() {
        return Err(format!(
            "{} conn 1: error: {:?} | conn 2: error: {:?}",
            id, r1, r2
        ));
    }

    // println!("{} total time: {}ms", id, start_time.elapsed().as_millis());
    Ok(GameResult {
        id: id,
        elapsed_time: start_time.elapsed(),
    })
}

struct Client {
    pub id: ClientID,
    pub join_token: String,
    finished: Option<oneshot::Receiver<Result<ConnResult, String>>>,
    dropped: Option<oneshot::Sender<bool>>,
}

type ClientID = usize;

impl Client {
    // Wait for game to be finished.
    pub async fn finished(&mut self) -> Result<ConnResult, String> {
        if let Some(rx) = self.finished.take() {
            match rx.await {
                Ok(r) => r,
                // error should already be fully tagged:
                Err(e) => Err(format!("{:?}", e)),
            }
        } else {
            Err("Game already finished!".into())
        }
    }
}

#[derive(Debug)]
struct ConnResult {
    pub game_id: GameID,
    pub client_id: ClientID,
    // pub state_history: Vec<State>,
    pub elapsed_time: std::time::Duration,
    pub avg_latency: std::time::Duration,
}

struct GameResult {
    pub id: GameID,
    pub elapsed_time: std::time::Duration,
}

type GameID = usize;

impl Drop for Client {
    fn drop(&mut self) {
        if let Some(tx) = self.dropped.take() {
            let _ = tx.send(true);
        }
    }
}

async fn spawn_client(
    game_id: GameID,
    client_id: ClientID,
    address: String,
    player_name: String,
    join_token: String,
    max_retries: u64,
    timeout: tokio::time::Duration,
    script: &'static [usize],
) -> Result<Client, String> {
    let (dropped_tx, mut dropped_rx) = oneshot::channel::<bool>();
    let (token_tx, token_rx) = oneshot::channel::<String>();
    let mut token_tx = Some(token_tx);
    let (result_tx, result_rx) = oneshot::channel::<Result<ConnResult, String>>();

    // TODO: needs proper escaping:
    let url = format!("{}?token={}&name={}", address, join_token, player_name);

    let start_time = std::time::Instant::now();
    tokio::spawn(async move {
        let mut conn: Option<WebSocketStream<TokioAdapter<TcpStream>>> = None;
        for i in 0..max_retries {
            match connect_async(&url).await {
                Ok((c, _)) => {
                    conn = Some(c);
                }
                Err(_) => {
                    // let msg = format!(
                    //     "DEBUG {} conn {}: connection error: {:?}",
                    //     game_id, client_id, e
                    // );
                    // println!("{}", msg);
                    sleep(Duration::from_secs(5 * (i + 1))).await;
                }
            };
        }
        if conn.is_none() {
            let _ = result_tx.send(Err(format!(
                "{} conn {}: connection failed after {} tries",
                game_id, client_id, max_retries
            )));
            return;
        }
        let mut conn = conn.unwrap();

        let mut done = false;
        // let mut player: Option<Player> = None;
        let mut my_team: char = ' ';
        // let mut state_history: Vec<State> = Vec::with_capacity(10);
        let mut current_move: usize = 0;
        while !done {
            tokio::select! {
                msg = conn.next() => {
                    match msg {
                        Some(Ok(msg)) => {
                            match msg {
                                Message::Text(text) => {
                                    // println!("conn {}: got Text: {}", id, text);
                                    let parsed: ToBrowser = serde_json::from_str(&text).unwrap();
                                    match parsed {
                                        ToBrowser::JoinedGame { token, player_id, state } => {
                                            if let Some(tx) = token_tx.take() {
                                                let _ = tx.send(token);
                                            }
                                            let player = state.players.iter().find(|p| p.id == player_id).map(|p| p.clone()).unwrap();
                                            my_team = player.team;
                                            // state_history.push(state);
                                        },
                                        ToBrowser::GameState(state) => {
                                            // state_history.push(state);
                                            // let state = state_history.last().unwrap();

                                            // check if game is over
                                            match state.winner {
                                                None => {
                                                    // take a turn if the game isn't over and it's my turn
                                                    if state.turn == my_team && current_move < script.len() {
                                                        let msg = FromBrowser::Move {
                                                            space: script[current_move],
                                                        };
                                                        current_move += 1;
                                                        let msg = serde_json::to_string(&msg).unwrap();
                                                        conn.send(Message::Text(msg)).await.unwrap();
                                                    }
                                                },
                                                Some(EndState::Draw) => {
                                                    // println!("conn {}: game ended in draw", id);
                                                    done = true;
                                                },
                                                Some(EndState::Win(team)) => {
                                                    if team == my_team {
                                                        // println!("conn {}: game ended in win", id);
                                                    } else {
                                                        // println!("conn {}: game ended in loss", id);
                                                    }
                                                    done = true;
                                                }

                                            }
                                        }
                                        ToBrowser::Error(msg) => {
                                            let msg = format!("{} conn {}: got unexpected Error from server: \"{}\"", game_id, client_id, msg);
                                            let _ = result_tx.send(Err(msg));
                                            return;
                                        }
                                    }
                                }
                                Message::Binary(_) => todo!(),
                                Message::Ping(data) => {
                                    conn.send(Message::Pong(data)).await.unwrap();
                                }
                                Message::Pong(_) => todo!(),
                                Message::Close(_) => {
                                    println!("{} conn {}: server closed connection", game_id, client_id);
                                    done = true;
                                }
                                Message::Frame(_) => todo!(),
                            }
                        }
                        Some(Err(msg)) => {
                            println!("{} conn {}: got Err: {:?}, exiting", game_id, client_id, msg);
                            done = true;
                        }
                        None => {
                            println!("{} conn {}: got None, exiting", game_id, client_id);
                            done = true;
                        }
                    }

                }
                _ = (&mut dropped_rx) => {
                    // println!("{} conn {}: got dropped msg, exiting with error", game_id, client_id);
                    let _ = result_tx.send(Err(format!("{} conn {}: dropped", game_id, client_id)));
                    return;
                }
                _ = sleep(timeout) => {
                    println!("{} conn {}: hit {}ms timeout waiting for it to be my turn, exiting", game_id, client_id, timeout.as_millis());
                    done = true;
                }
            }
        }

        // println!("conn {}: exiting", id);
        result_tx
            .send(Ok(ConnResult {
                game_id: game_id,
                client_id: client_id,
                // state_history: state_history,
                elapsed_time: start_time.elapsed(),
                avg_latency: std::time::Duration::from_millis(0), // TODO
            }))
            .unwrap();
    });

    // Wait for a join token from the server, or cancel after timeout.
    tokio::select! {
        token = token_rx => {
            match token {
                Ok(token) => {
                    Ok(Client {
                        id: client_id,
                        join_token: token,
                        finished: Some(result_rx),
                        dropped: Some(dropped_tx),
                    })
                },
                Err(_) => {
                    // we end up here if the other end of the channel got dropped
                    Err(format!("{} conn {}: could not get token from server, as server process exited too soon", game_id, client_id).into())
                }
            }
        }
        _ = sleep(timeout) => {
            return Err(format!("{} conn {}: hit {}ms timeout waiting for token", game_id, client_id, timeout.as_millis()).into());
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
enum ToBrowser {
    JoinedGame {
        token: String,
        player_id: PlayerID,
        state: State,
    },
    GameState(State),
    Error(String),
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
enum FromBrowser {
    ChatMsg { text: String },
    ChangeName { new_name: String },
    Move { space: usize },
    Rematch,
}

type PlayerID = i32;

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
enum EndState {
    Win(char),
    Draw,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
struct Player {
    pub id: PlayerID,
    pub team: char,
    pub name: String,
    pub wins: i32,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
struct State {
    pub turn: char,
    pub winner: Option<EndState>,
    pub players: Vec<Player>,
    pub board: Vec<char>,
    pub chat: Vec<ChatMessage>,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
struct ChatMessage {
    pub id: usize,
    pub source: ChatMessageSource,
    pub text: String,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
enum ChatMessageSource {
    Player(PlayerID),
    System,
}
