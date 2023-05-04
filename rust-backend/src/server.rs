// Server state and stats
use crate::game;
use rand::{distributions::Alphanumeric, Rng};
use std::collections::HashMap;
use std::fmt::{Display, Formatter};
use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::watch;
use tracing::debug;

#[derive(Debug)]
pub struct State {
    pub frontend_url: String,
    pub games: RwLock<HashMap<String, Arc<Mutex<game::Game>>>>,
}

impl State {
    pub fn new(frontend_url: String) -> State {
        State {
            frontend_url,
            games: RwLock::new(HashMap::new()),
        }
    }

    pub fn delete_game(&self, id: &str) {
        let mut games = self.games.write().unwrap();
        games.remove(id);
    }
}

pub fn join_or_new_game(
    state: Arc<State>,
    token: Option<String>,
    player_name: Option<String>,
) -> Result<Connection, String> {
    let mut is_new_game = false;
    let game: Arc<Mutex<game::Game>> = token
        .clone()
        .and_then(|token| {
            // if we have a token, try to get the game matching the token
            let games = state.games.read().unwrap();
            games.get(&token).map(|g| g.clone())
        })
        .unwrap_or_else(|| {
            // if after that we still don't have a game, create a new one
            is_new_game = true;

            let id: String = token.unwrap_or_else(|| random_token());
            // TODO: when generating random token, check for collisions

            let (game, mut rx) = game::Game::new(id.clone());

            let game = Arc::new(Mutex::new(game));

            // spawn cleanup process
            {
                let state = state.clone();
                let id = id.clone();
                tokio::spawn(async move {
                    while rx.changed().await.is_ok() {
                        if rx.borrow().players.len() == 0 {
                            break;
                        }
                    }

                    debug!("Game '{}' is empty, deleting", &id);
                    state.delete_game(&id);
                });
            }

            state.games.write().unwrap().insert(id, game.clone());
            game
        });

    let mut unlocked_game = game.lock().unwrap();

    match unlocked_game.add_player(player_name.unwrap_or_else(|| "Unnamed Player".to_string())) {
        Ok(_player) => {
            unlocked_game.broadcast_state();

            Ok(Connection {
                game_id: unlocked_game.id.clone(),
                player: _player,
                game: game.clone(),
                is_new_game: is_new_game,
                game_state: unlocked_game.state_changes.subscribe(),
                // game_empty: self.empty_games_tx.clone(),
            })
        }
        Err(e) => Err(e),
    }
}

fn random_token() -> String {
    return rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(7)
        .map(char::from)
        .collect();
}

impl Display for State {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "AppState(GameCount: {})",
            self.games.read().unwrap().len()
        )
    }
}

pub struct Connection {
    pub game_id: String,
    pub game: Arc<Mutex<game::Game>>,
    pub player: game::Player,
    pub is_new_game: bool,
    pub game_state: watch::Receiver<game::State>,
}

impl Drop for Connection {
    fn drop(&mut self) {
        debug!(
            "Connection: Player {:?} disconnected, removing from game",
            self.player
        );
        let mut game = self.game.lock().unwrap();
        game.remove_player(self.player.id);
        game.broadcast_state();
    }
}
