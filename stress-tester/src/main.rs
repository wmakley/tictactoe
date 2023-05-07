use async_tungstenite::tokio::connect_async;
use async_tungstenite::tungstenite::Message;
use clap::Parser;
use futures::prelude::*;
use serde::{Deserialize, Serialize};
use tokio::sync::oneshot;
use tokio::time::{sleep, Duration};

#[derive(Debug, Parser)]
struct Args {
    address: String,
}

static X_SCRIPT: [usize; 4] = [4, 1, 2, 8];
static O_SCRIPT: [usize; 4] = [0, 7, 6, 3];

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    // println!("Options: {:?}", args);

    play_test_game(&args.address).await?;
    Ok(())
}

async fn play_test_game(address: &str) -> Result<(), Box<dyn std::error::Error>> {
    let mut client1 = spawn_client(
        1,
        address.to_string(),
        String::from("P1"),
        String::from(""),
        &X_SCRIPT,
    )
    .await?;
    let mut client2 = spawn_client(
        2,
        address.to_string(),
        String::from("P2"),
        client1.join_token.clone(),
        &O_SCRIPT,
    )
    .await?;

    let (_h1, _h2) = futures::try_join!(client1.finished(), client2.finished())?;
    println!("game finished");
    // println!("p1 history: {:?}", h1);
    // println!("p2 history: {:?}", h2);

    Ok(())
}

struct Client {
    pub id: ClientID,
    pub join_token: String,
    finished: Option<oneshot::Receiver<Result<Vec<State>, String>>>,
    dropped: Option<oneshot::Sender<bool>>,
}

type ClientID = usize;

impl Client {
    // Wait for game to be finished.
    pub async fn finished(&mut self) -> Result<Vec<State>, String> {
        if let Some(rx) = self.finished.take() {
            match rx.await {
                Ok(r) => r,
                Err(e) => Err(format!("{:?}", e)),
            }
        } else {
            Err("Game already finished!".into())
        }
    }
}

impl Drop for Client {
    fn drop(&mut self) {
        if let Some(tx) = self.dropped.take() {
            let _ = tx.send(true);
        }
    }
}

async fn spawn_client(
    id: ClientID,
    address: String,
    player_name: String,
    join_token: String,
    script: &'static [usize],
) -> Result<Client, String> {
    let (dropped_tx, mut dropped_rx) = oneshot::channel::<bool>();
    let (token_tx, token_rx) = oneshot::channel::<String>();
    let mut token_tx = Some(token_tx);
    let (finished_tx, finished_rx) = oneshot::channel::<Result<Vec<State>, String>>();

    // TODO: needs proper escaping:
    let url = format!("{}?token={}&name={}", address, join_token, player_name);

    tokio::spawn(async move {
        let (mut conn, _) = connect_async(url).await.unwrap();

        let mut done = false;
        let mut player: Option<Player> = None;
        let mut my_team: char = ' ';
        let mut state_history: Vec<State> = Vec::with_capacity(20);
        let mut current_move: usize = 0;
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
                                        ToBrowser::JoinedGame { token, player_id, state } => {
                                            if let Some(tx) = token_tx.take() {
                                                let _ = tx.send(token);
                                            }
                                            player = state.players.iter().find(|p| p.id == player_id).map(|p| p.clone());
                                            assert!(player.is_some(), "could not find player in players vec");
                                            my_team = player.unwrap().team;
                                            state_history.push(state);
                                        },
                                        ToBrowser::GameState(state) => {
                                            state_history.push(state);
                                            let state = state_history.last().unwrap();

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
                                                    println!("conn {}: game ended in draw", id);
                                                    done = true;
                                                },
                                                Some(EndState::Win(team)) => {
                                                    if team == my_team {
                                                        println!("conn {}: game ended in win", id);
                                                    } else {
                                                        println!("conn {}: game ended in loss", id);
                                                    }
                                                    done = true;
                                                }

                                            }
                                        }
                                        ToBrowser::Error(_) => todo!(),
                                    }
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
                _ = (&mut dropped_rx) => {
                    println!("conn {}: got done msg probably because client dropped, exiting", id);
                    done = true;
                }
                _ = sleep(Duration::from_secs(10)) => {
                    println!("conn {}: hit 10s timeout waiting for it to be my turn, exiting", id);
                    done = true;
                }
            }
        }

        println!("conn {}: exiting", id);
        finished_tx.send(Ok(state_history)).unwrap();
    });

    // Wait for a join token from the server, or cancel after 5s.
    tokio::select! {
        token = token_rx => {
            match token {
                Ok(token) => {
                    Ok(Client {
                        id: id,
                        join_token: token,
                        finished: Some(finished_rx),
                        dropped: Some(dropped_tx),
                    })
                },
                Err(e) => {
                    Err(format!("conn {}: unexpected error waiting for token for client {:?}", id, e).into())
                }
            }
        }
        _ = sleep(Duration::from_secs(5)) => {
            return Err(format!("conn {}: hit 5s timeout waiting for token for client", id).into());
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
