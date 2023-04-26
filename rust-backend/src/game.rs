use std::fmt::Display;

use serde::{Deserialize, Serialize};
use tokio::sync::watch;
use tracing::debug;

#[derive(Debug)]
pub struct Game {
    pub id: String,
    pub state: State,
    pub state_changes: watch::Sender<State>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct State {
    pub turn: char,
    pub winner: Option<EndState>,
    pub players: Vec<Player>,
    pub board: Vec<char>,
    pub chat: Vec<ChatMessage>,
}

impl State {
    pub fn new() -> State {
        State {
            turn: 'X',
            winner: None,
            players: Vec::new(),
            board: vec![' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '],
            chat: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub enum EndState {
    Win(char),
    Draw,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Player {
    pub id: PlayerID,
    pub team: char,
    pub name: String,
    pub wins: i32,
}

pub type PlayerID = i32;

impl Display for Player {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} ({})", self.name, self.team)
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ChatMessage {
    pub id: usize,
    pub source: ChatMessageSource,
    pub text: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub enum ChatMessageSource {
    Player(PlayerID),
    System,
}

impl Game {
    pub fn new(id: String) -> (Game, watch::Receiver<State>) {
        let state = State::new();
        let (tx, rx) = watch::channel(state.clone());

        let game = Game {
            id: id,
            state: state,
            state_changes: tx,
        };

        return (game, rx);
    }

    pub fn add_player(&mut self, name: String) -> Result<Player, String> {
        if self.state.players.len() >= 2 {
            return Err("Game is full".to_string());
        }

        let last_player = self.state.players.last();

        let id = last_player.map(|p| p.id + 1).unwrap_or(0);
        let team = match last_player.map(|p| p.team) {
            Some('X') => 'O',
            _ => 'X',
        };

        let player = Player {
            id: id,
            team: team,
            name: name,
            wins: 0,
        };
        self.state.players.push(player.clone());
        self.add_chat_message(
            ChatMessageSource::System,
            format!("{} ({}) has joined the game", player.name, player.team),
        );
        Ok(player)
    }

    /// internal trusted function that always succeeds unless the id is bad
    fn update_player_name(&mut self, id: PlayerID, name: String) -> Result<(), String> {
        let player = self.get_player_mut(id).ok_or("Invalid player ID")?;
        player.name = name;
        Ok(())
    }

    /// Internal trusted version
    fn add_chat_message(&mut self, source: ChatMessageSource, text: String) {
        let id = self.state.chat.len();
        self.state.chat.push(ChatMessage {
            id: id,
            source: source,
            text: text,
        });
    }

    pub fn get_player_index(&self, id: PlayerID) -> Option<usize> {
        self.state.players.iter().position(|p| p.id == id)
    }

    pub fn get_player_index_by_team(&self, team: char) -> Option<usize> {
        self.state.players.iter().position(|p| p.team == team)
    }

    pub fn get_player_mut(&mut self, id: PlayerID) -> Option<&mut Player> {
        self.state.players.iter_mut().find(|p| p.id == id)
    }

    pub fn remove_player(&mut self, id: PlayerID) {
        let player = match self.state.players.iter().find(|p| p.id == id) {
            Some(p) => p,
            None => return,
        };
        self.add_chat_message(
            ChatMessageSource::System,
            format!("{} has left the game", player.name),
        );
        self.state.players.retain(|p| p.id != id);
    }

    pub fn take_turn(&mut self, player_id: PlayerID, space: usize) -> Result<(), String> {
        if self.state.players.len() < 2 {
            return Err("Not enough players".to_string());
        }

        if self.state.winner.is_some() {
            return Err("Game is over".to_string());
        }

        let player_idx = match self.get_player_index(player_id) {
            Some(idx) => idx,
            None => return Err("Invalid player ID".to_string()),
        };
        let team = self.state.players[player_idx].team;

        if self.state.turn != self.state.players[player_idx].team {
            return Err("Not your turn".to_string());
        }

        if self.state.board[space] != ' ' {
            return Err("Invalid move".to_string());
        }

        self.state.board[space] = team;
        self.state.turn = if self.state.turn == 'X' { 'O' } else { 'X' };

        self.add_chat_message(
            ChatMessageSource::Player(player_id),
            format!("Played {} at ({}, {}).", team, space % 3 + 1, space / 3 + 1),
        );

        if let Some(winning_team) = self.check_for_win() {
            self.state.winner = Some(EndState::Win(winning_team));
            let winner_idx = self.get_player_index_by_team(winning_team).unwrap();
            self.state.players[winner_idx].wins += 1;
            self.add_chat_message(
                ChatMessageSource::System,
                format!("{} wins!", self.state.players[winner_idx]),
            );
        } else if self.check_for_draw() {
            self.state.winner = Some(EndState::Draw);
            self.add_chat_message(ChatMessageSource::System, "It's a draw!".to_string());
        }

        Ok(())
    }

    pub fn broadcast_state(&self) {
        self.state_changes.send_replace(self.state.clone());
    }

    fn check_for_win(&self) -> Option<char> {
        let winning_combos = [
            [0, 1, 2],
            [3, 4, 5],
            [6, 7, 8],
            [0, 3, 6],
            [1, 4, 7],
            [2, 5, 8],
            [0, 4, 8],
            [2, 4, 6],
        ];

        for combo in winning_combos.iter() {
            let mut winner = self.state.board[combo[0]];
            if winner == ' ' {
                continue;
            }

            for i in 1..3 {
                if self.state.board[combo[i]] != winner {
                    winner = ' ';
                    break;
                }
            }

            if winner != ' ' {
                return Some(winner);
            }
        }

        None
    }

    fn check_for_draw(&self) -> bool {
        self.state.board.iter().all(|&c| c != ' ')
    }

    fn reset(&mut self) {
        self.state.board.iter_mut().for_each(|c| *c = ' ');
        self.state.turn = 'X';
        self.state.winner = None;
    }
    fn swap_teams(&mut self) {
        self.state.players.iter_mut().for_each(|p| {
            if p.team == 'X' {
                p.team = 'O';
            } else {
                p.team = 'X';
            }
        });
    }

    pub fn handle_msg(&mut self, player_id: PlayerID, msg: FromBrowser) -> Result<bool, String> {
        debug!("Game: Handle Msg: {:?}", msg);
        match msg {
            FromBrowser::ChatMsg { text } => {
                let trimmed = text.trim();
                if trimmed.len() == 0 {
                    return Err("Empty message".to_string());
                }
                if trimmed.len() > 500 {
                    return Err("Message too long".to_string());
                }
                self.add_chat_message(ChatMessageSource::Player(player_id), trimmed.to_string());
            }
            FromBrowser::ChangeName { new_name } => {
                let mut trimmed = new_name.trim();
                if trimmed.len() == 0 {
                    trimmed = "Unnamed Player";
                } else if trimmed.len() > 32 {
                    trimmed = &trimmed[..32];
                }
                self.update_player_name(player_id, trimmed.to_string())
                    .unwrap();
                self.add_chat_message(
                    ChatMessageSource::Player(player_id),
                    format!("Now my name is \"{}\"!", new_name),
                );
            }
            FromBrowser::Move { space } => self.take_turn(player_id, space)?,
            FromBrowser::Rematch => {
                self.add_chat_message(ChatMessageSource::Player(player_id), "Rematch!".to_string());
                self.add_chat_message(
                    ChatMessageSource::System,
                    "Players have swapped sides.".to_string(),
                );
                self.reset();
                self.swap_teams();
            }
        }
        Ok(true)
    }
}

#[derive(Debug, Clone, Deserialize)]
pub enum FromBrowser {
    ChatMsg { text: String },
    ChangeName { new_name: String },
    Move { space: usize },
    Rematch,
}

#[derive(Debug, Clone, Serialize)]
pub enum ToBrowser {
    JoinedGame {
        token: String,
        player_id: PlayerID,
        state: State,
    },
    GameState(State),
    Error(String),
}
