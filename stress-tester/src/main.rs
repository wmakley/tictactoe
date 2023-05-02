use async_tungstenite::tokio::connect_async;
// use async_tungstenite::tungstenite::Message;
use clap::Parser;
use futures::prelude::*;
use serde::{Deserialize, Serialize};

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
            assert!(token.len() > 0);
            assert!(player_id == 1);
            assert!(state.players.len() == 2);
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
            assert!(token == initial_token);
            assert!(player_id == 2);
            assert!(state.players.len() == 2);
        }
        _ => {
            return Err(format!("Received unexpected message: {:?}", msg).into());
        }
    };

    Ok(())
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
