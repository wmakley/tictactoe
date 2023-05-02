// Server state and stats
use crate::game;
use rand::{distributions::Alphanumeric, Rng};
use std::collections::HashMap;
use std::fmt::{Display, Formatter};
use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::watch::Receiver;

#[derive(Debug)]
pub struct State {
    pub frontend_url: String,
    pub games: RwLock<HashMap<String, Arc<Mutex<game::Game>>>>,
}

pub struct JoinGameResult {
    pub id: String,
    pub player: game::Player,
    pub game: Arc<Mutex<game::Game>>,
    // Clone of the state
    pub game_state: game::State,
    pub receive_from_game: Receiver<game::State>,
}

impl State {
    pub fn new(frontend_url: String) -> State {
        State {
            frontend_url,
            games: RwLock::new(HashMap::new()),
        }
    }

    pub fn join_or_new_game(
        &self,
        token: Option<String>,
        player_name: Option<String>,
    ) -> Result<JoinGameResult, String> {
        let game: Arc<Mutex<game::Game>> = token
            .clone()
            .and_then(|token| {
                // if we have a token, try to get the game matching the token
                let games = self.games.read().unwrap();
                games.get(&token).map(|g| g.clone())
            })
            .unwrap_or_else(|| {
                // if after that we still don't have a game, create a new one

                let id: String = token.unwrap_or_else(|| random_token());
                // TODO: when generating random token, check for collisions

                let (game, _) = game::Game::new(id.clone());

                let game = Arc::new(Mutex::new(game));

                self.games.write().unwrap().insert(id, game.clone());
                game
            });

        let mut unlocked_game = game.lock().unwrap();

        match unlocked_game.add_player(player_name.unwrap_or_else(|| "Unnamed Player".to_string()))
        {
            Ok(_player) => {
                unlocked_game.broadcast_state();

                Ok(JoinGameResult {
                    id: unlocked_game.id.clone(),
                    player: _player,
                    game: game.clone(),
                    game_state: unlocked_game.state.clone(),
                    receive_from_game: unlocked_game.state_changes.subscribe(),
                })
            }
            Err(e) => Err(e),
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

impl Display for State {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "AppState(GameCount: {})",
            self.games.read().unwrap().len()
        )
    }
}
