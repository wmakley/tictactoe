use async_tungstenite::tokio::connect_async;
use async_tungstenite::tungstenite::Message;
use clap::Parser;
use futures::prelude::*;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;
use tokio::sync::oneshot;

#[derive(Debug, Parser)]
struct Args {
    address: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    // println!("Options: {:?}", args);

    play_test_game(&args.address).await?;
    Ok(())
}

async fn play_test_game(address: &str) -> Result<(), Box<dyn std::error::Error>> {
    let (tx, mut rx) = mpsc::channel::<TestGameMsg>(20);

    let client1 = spawn_client(1, address.to_string(), String::from("P1"), String::from(""), tx.clone());
    let client2 = spawn_client(2, address.to_string(), String::from("P2"), client1.join_token().await, tx);

    // assert client1 state == client2 state

    // tell client1 to make a move

    // assert both states changed and move happened

    // could make assertions within the client as well

    let (mut conn1, _) = connect_async(address).await?;
    let msg = conn1.next().await.ok_or("didn't receive anything")??;
    let msg: ToBrowser = serde_json::from_str(&msg.to_string())?;

    let (initial_token, _initial_state) = match msg {
        ToBrowser::JoinedGame {
            token,
            player_id,
            state,
        } => {
            // println!("JoinedGame token: {}, player_id: {}", token, player_id);
            assert!(token.len() > 0, "token is empty");
            assert!(player_id == 1, "player_id is not 1");
            assert!(state.players.len() == 1, "players.len() is not 1");
            assert!(state.chat.len() == 1, "chat.len() is not 1");
            (token, state)
        }
        _ => {
            return Err(format!("Received unexpected message: {:?}", msg).into());
        }
    };

    let (mut conn2, _) = connect_async(format!("{}?token={}", address, initial_token)).await?;
    let msg = conn2.next().await.ok_or("didn't receive anything")??;
    let msg: ToBrowser = serde_json::from_str(&msg.to_string())?;
    match msg {
        ToBrowser::JoinedGame {
            token,
            player_id,
            state,
        } => {
            assert!(token == initial_token, "token does not match");
            assert!(player_id == 2, "player_id is not 2");
            assert!(state.players.len() == 2, "players.len() is not 2");
            assert!(state.chat.len() == 2, "chat.len() is not 2");
        }
        _ => {
            return Err(format!("Received unexpected message: {:?}", msg).into());
        }
    };

    let msg = conn1.next().await.ok_or("didn't receive anything")??;
    println!("next msg on conn 1: {:?}", msg);
    // let msg: ToBrowser = serde_json::from_str(&msg.to_string())?;

    let msg = conn2.next().await.ok_or("didn't receive anything")??;
    println!("next msg on conn 2: {:?}", msg);

    // let msg: ToBrowser = serde_json::from_str(&msg.to_string())?;

    Ok(())
}

type TestGameMsg = (u8, ToBrowser);

struct Client {
    pub id: u8,
    join_token: String,
    player: Option<Player>,
    server_messages: mpsc::Receiver<ToBrowser>,
    dropped: Option<oneshot::Sender<bool>>,
}

impl Client {
    pub async fn join_token() -> Option<String> {

    }
}

impl Drop for Client {
    fn drop(&mut self) {
        if let Some(tx) = self.dropped.take() {
            let _ = tx.send(true);
        }
    }
}

async fn spawn_client(id: u8, address: String, player_name: String, join_token: String, tx: mpsc::Sender<TestGameMsg>) -> Client {
    let (done_tx, mut done_rx) = oneshot::channel::<bool>();
    let (state_tx, state_rx) = mpsc::channel::<State>(100);

    tokio::spawn(async move {
        let (mut conn, _) = connect_async(address).await.unwrap();

        let mut done = false;
        while !done {
            tokio::select! {
                msg = conn.next() => {
                    match msg {
                        Some(Ok(msg)) => {
                            match msg {
                                Message::Text(text) => {
                                    println!("conn {}: got Text: {}", id, text);
                                    let parsed: ToBrowser = serde_json::from_str(&text).unwrap();
                                    match parsed {
                                        ToBrowser::JoinedGame { token, player_id, state } => todo!(),
                                        ToBrowser::GameState(_) => todo!(),
                                        ToBrowser::Error(_) => todo!(),
                                    }
                                    tx.send((id, parsed)).await.unwrap();
                                }
                                Message::Binary(_) => todo!(),
                                Message::Ping(data) => {
                                    conn.send(Message::Pong(data)).await.unwrap();
                                }
                                Message::Pong(_) => todo!(),
                                Message::Close(_) => {
                                    println!("conn {}: server closed connection", id);
                                    done = true;
                                }
                                Message::Frame(_) => todo!(),
                            }
                        }
                        Some(Err(msg)) => {
                            println!("conn {}: got Err: {:?}, exiting", id, msg);
                            done = true;
                        }
                        None => {
                            println!("conn {}: got None, exiting", id);
                            done = true;
                        }
                    }

                }
                _ = (&mut done_rx) => {
                    done = true;
                }
            }
        }

        println!("exiting select loop {}", id);
    });
    Client {
        id: id,
        join_token: join_token,
        game_state_rx: state_rx,
        dropped: Some(done_tx),
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
