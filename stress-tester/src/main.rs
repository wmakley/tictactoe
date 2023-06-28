use async_tungstenite::{tokio::connect_async, tungstenite::Message};
use clap::Parser;
use futures::prelude::*;
use serde::{Deserialize, Serialize};
use tokio::{
    sync::oneshot,
    task::JoinSet,
    time::{sleep, Duration, Instant},
};

#[derive(Debug, Parser)]
struct Args {
    address: String,
    n: usize,
}

static X_MOVES: [usize; 4] = [4, 1, 2, 8];
static O_MOVES: [usize; 4] = [0, 7, 6, 3];

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    // println!("Options: {:?}", args);

    // play n games
    let mut set = JoinSet::new();
    for i in 0..args.n {
        set.spawn(play_test_game(i, args.address.clone()));
    }

    let mut overall_times: Vec<Duration> = Vec::with_capacity(args.n);
    let mut connection_times: Vec<Duration> = Vec::with_capacity(args.n * 2);
    let mut game_times: Vec<Duration> = Vec::with_capacity(args.n * 2);
    let mut p1_join_times: Vec<Duration> = Vec::with_capacity(args.n);
    let mut p2_join_times: Vec<Duration> = Vec::with_capacity(args.n);
    let mut turn_latency_samples: Vec<Duration> = Vec::with_capacity(args.n * 8);

    let start_time = Instant::now();
    while let Some(r) = set.join_next().await {
        match r {
            Ok(Ok(result)) => {
                overall_times.push(result.overall_time);

                connection_times.push(result.p1_stats.time_to_connect);
                connection_times.push(result.p2_stats.time_to_connect);

                game_times.push(result.p1_stats.game_time);
                game_times.push(result.p2_stats.game_time);

                p1_join_times.push(result.p1_stats.time_to_join_response);
                p2_join_times.push(result.p2_stats.time_to_join_response);

                turn_latency_samples.extend(result.p1_stats.turn_latency_samples);
                turn_latency_samples.extend(result.p2_stats.turn_latency_samples);
            }
            Ok(Err(e)) => println!("Game ended with error: {}", e),
            Err(e) => println!("Join Error: {:?}", e),
        }
    }
    let elapsed = start_time.elapsed();

    // reporting:

    println!(
        "played {} of {} requested games to completion in {:.2}s",
        overall_times.len(),
        args.n,
        elapsed.as_secs_f64()
    );

    if !overall_times.is_empty() {
        println!(
            "games finished per second: {:.2}",
            overall_times.len() as f64 / elapsed.as_secs_f64()
        );
        println!(
            "mean overall game length including time to connect: {}ms",
            overall_times.iter().sum::<Duration>().as_millis() / overall_times.len() as u128
        );
    }
    if !connection_times.is_empty() {
        println!(
            "mean time to connect: {}ms",
            connection_times.iter().sum::<Duration>().as_millis() / connection_times.len() as u128
        );
    }
    if !p1_join_times.is_empty() {
        println!(
            "mean player 1 (X) wait to join game: {}ms",
            p1_join_times.iter().sum::<Duration>().as_millis() / p1_join_times.len() as u128
        )
    }
    if !p2_join_times.is_empty() {
        println!(
            "mean player 2 (O) wait to join game: {}ms",
            p2_join_times.iter().sum::<Duration>().as_millis() / p2_join_times.len() as u128
        )
    }
    if !game_times.is_empty() {
        println!(
            "mean game length after connection: {}ms",
            game_times.iter().sum::<Duration>().as_millis() / game_times.len() as u128
        );
    }
    if !turn_latency_samples.is_empty() {
        let sum = turn_latency_samples.iter().sum::<Duration>();
        let avg = sum.as_millis() / turn_latency_samples.len() as u128;
        println!("mean turn/response latency: {}ms", avg);
    }

    Ok(())
}

struct GameResult {
    /// The overall time for both connections and the game to complete
    pub overall_time: Duration,
    /// Stats from the player 1 client
    pub p1_stats: ClientResult,
    /// Stats from the player 2 client
    pub p2_stats: ClientResult,
}

type GameID = usize;

async fn play_test_game(id: GameID, address: String) -> Result<GameResult, String> {
    let start_time = Instant::now();

    // let max_connect_retries = 0;
    let global_timeout = Duration::from_secs(30);

    let mut client1 = spawn_client(
        id,
        1,
        address.to_string(),
        String::from("P1"),
        String::from(""),
        // max_connect_retries,
        global_timeout,
        &X_MOVES,
    )
    .await?;
    // client1 will be dropped (automatic disconnect) if client2 fails now:
    let mut client2 = spawn_client(
        id,
        2,
        address.to_string(),
        String::from("P2"),
        client1.join_token.clone(),
        // max_connect_retries,
        global_timeout,
        &O_MOVES,
    )
    .await?;

    let (r1, r2) = futures::join!(client1.finished(), client2.finished());
    let overall_time = start_time.elapsed();
    if r1.is_err() || r2.is_err() {
        return Err(format!(
            "{} conn 1: error: {:?} | conn 2: error: {:?}",
            id, r1, r2
        ));
    }
    let r1 = r1.unwrap();
    let r2 = r2.unwrap();

    // let mut latencies = r1.turn_latency_samples;
    // latencies.extend(r2.turn_latency_samples);

    // let sum = latencies.iter().sum::<Duration>();
    // let avg = sum.as_millis() / latencies.len() as u128;

    // println!(
    //     "{} total time: {}ms, avg latency: {}ms",
    //     id,
    //     start_time.elapsed().as_millis(),
    //     avg
    // );
    Ok(GameResult {
        overall_time: overall_time,
        p1_stats: r1,
        p2_stats: r2,
    })
}

struct Client {
    pub join_token: String,
    finished: Option<oneshot::Receiver<Result<ClientResult, String>>>,
    dropped: Option<oneshot::Sender<bool>>,
}

type ClientID = usize;

impl Client {
    // Wait for game to be finished.
    pub async fn finished(&mut self) -> Result<ClientResult, String> {
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
struct ClientResult {
    // pub overall_time: Duration,
    pub time_to_connect: Duration,
    pub time_to_join_response: Duration,
    pub game_time: Duration,
    pub turn_latency_samples: Vec<Duration>,
}

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
    // max_retries: u64,
    timeout: tokio::time::Duration,
    moves: &'static [usize],
) -> Result<Client, String> {
    let (dropped_tx, mut dropped_rx) = oneshot::channel::<bool>();
    let (token_tx, token_rx) = oneshot::channel::<Result<String, String>>();
    let mut token_tx = Some(token_tx);
    let (result_tx, result_rx) = oneshot::channel::<Result<ClientResult, String>>();

    // TODO: needs proper escaping:
    let url = format!("{}?token={}&name={}", address, join_token, player_name);

    tokio::spawn(async move {
        let overall_start_time = Instant::now();
        let mut conn = match connect_async(&url).await {
            Ok((conn, _resp)) => conn,
            Err(e) => {
                let msg = format!("{} conn {}: {}", game_id, client_id, e);
                // println!("{}", msg);
                if let Some(tx) = token_tx.take() {
                    let _ = tx.send(Err(msg.clone()));
                }
                let _ = result_tx.send(Err(msg));
                return;
            }
        };
        let time_to_connect = overall_start_time.elapsed();

        let join_game_start_time = Instant::now();
        let mut time_to_join_response: Option<Duration> = None;
        let mut result: Option<Result<(), String>> = None;
        let mut my_team: char = ' ';
        let mut current_move: usize = 0;
        let mut turn_latency_samples: Vec<Duration> = Vec::with_capacity(10);
        let mut time_of_last_request: Option<Instant> = None;
        while result.is_none() {
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
                                            time_to_join_response = Some(join_game_start_time.elapsed());
                                            if let Some(tx) = token_tx.take() {
                                                let _ = tx.send(Ok(token));
                                            }
                                            let player = state.players.iter().find(|p| p.id == player_id).map(|p| p.clone()).unwrap();
                                            my_team = player.team;
                                            // state_history.push(state);
                                        },
                                        ToBrowser::GameState(state) => {
                                            // println!("{} conn {}: new state: {:?}", game_id, client_id, state);

                                            if let Some(t) = time_of_last_request.take() {
                                                turn_latency_samples.push(t.elapsed());
                                            }

                                            // check if game is over
                                            match state.winner {
                                                None => {
                                                    // take a turn if the game if it's my turn
                                                    if state.turn == my_team && state.players.len() == 2 && current_move < moves.len() {

                                                        // give time for server update both players
                                                        // - mitigates race condition in go server,
                                                        //   proving the existence of said race condition
                                                        // sleep(Duration::from_millis(100)).await;

                                                        let msg = FromBrowser::Move {
                                                            space: moves[current_move],
                                                        };
                                                        current_move += 1;
                                                        let msg = serde_json::to_string(&msg).unwrap();
                                                        conn.send(Message::Text(msg)).await.unwrap();
                                                        time_of_last_request = Some(Instant::now());
                                                    }
                                                },
                                                Some(EndState::Draw) => {
                                                    // println!("conn {}: game ended in draw", id);
                                                    result = Some(Ok(()));
                                                },
                                                Some(EndState::Win(team)) => {
                                                    if team == my_team {
                                                        // println!("conn {}: game ended in win", id);
                                                    } else {
                                                        // println!("conn {}: game ended in loss", id);
                                                    }
                                                    result = Some(Ok(()));
                                                }

                                            }
                                        }
                                        ToBrowser::Error(msg) => {
                                            result = Some(Err(format!("{} conn {}: got unexpected Error from server: \"{}\"", game_id, client_id, msg)));
                                        }
                                    }
                                }
                                Message::Binary(_) => todo!(),
                                Message::Ping(data) => {
                                    conn.send(Message::Pong(data)).await.unwrap();
                                }
                                Message::Pong(_) => todo!(),
                                Message::Close(_) => {
                                    result = Some(Err(format!("{} conn {}: server closed connection", game_id, client_id)));
                                }
                                Message::Frame(_) => todo!(),
                            }
                        }
                        Some(Err(msg)) => {
                            result = Some(Err(format!("{} conn {}: got Err: {:?}, exiting", game_id, client_id, msg)));
                        }
                        None => {
                            result = Some(Err(format!("{} conn {}: got None, exiting", game_id, client_id)));
                        }
                    }

                }
                _ = (&mut dropped_rx) => {
                    println!("{} conn {}: dropped", game_id, client_id);
                    result = Some(Err(format!("{} conn {}: dropped", game_id, client_id)));
                }
                _ = sleep(timeout) => {
                    result = Some(Err(format!("{} conn {}: hit {}ms timeout waiting for it to be my turn, exiting", game_id, client_id, timeout.as_millis())));
                }
            }
        }

        let result = result.unwrap();
        match result {
            Err(msg) => {
                println!("{}", msg);
                // There may be nobody listening on error in some cases, so
                // ignore failures here.
                let _ = result_tx.send(Err(msg));
                return;
            }
            Ok(()) => {
                // println!("conn {}: exiting", id);
                // There should always be someone listening to successes,
                // so failure to send result is hard failure.
                result_tx
                    .send(Ok(ClientResult {
                        // overall_time: overall_start_time.elapsed(),
                        time_to_connect: time_to_connect,
                        time_to_join_response: time_to_join_response.unwrap(),
                        game_time: join_game_start_time.elapsed(),
                        turn_latency_samples: turn_latency_samples,
                    }))
                    .unwrap();
            }
        }
        // we depend on RAII to close the connection
    });

    // Wait for a join token from the server, or cancel after timeout.
    tokio::select! {
        token = token_rx => {
            match token {
                Ok(Ok(token)) => {
                    Ok(Client {
                        join_token: token,
                        finished: Some(result_rx),
                        dropped: Some(dropped_tx),
                    })
                },
                Ok(Err(conn_err)) => {
                    Err(conn_err)
                }
                Err(_recv_err) => {
                    // we end up here if the other end of the channel got dropped
                    Err(format!("{} conn {}: connection failed", game_id, client_id).into())
                }
            }
        }
        _ = sleep(timeout) => {
            Err(format!("{} conn {}: hit {}ms timeout waiting for token", game_id, client_id, timeout.as_millis()).into())
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
