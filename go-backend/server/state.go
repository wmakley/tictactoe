package server

import (
	"errors"
	"go-backend/game"
	"log"
	"strings"
	"sync"
	"time"
)

type State interface {
	JoinOrNewGame(id string, playerName string) (game.Game, game.Player, <-chan *game.State, error)
	StartCleanup()
	EmptyGames() chan string
}

func NewState() State {
	return &serverState{
		games:      make(map[string]game.Game),
		mutex:      sync.Mutex{},
		emptyGames: make(chan string, 10),
	}
}

type serverState struct {
	games      map[string]game.Game
	mutex      sync.Mutex
	emptyGames chan string
}

// allowing users to lock/unlock is not part of the interface
//func (s *serverState) Lock() {
//	s.mutex.Lock()
//}
//
//func (s *serverState) Unlock() {
//	s.mutex.Unlock()
//}

func (s *serverState) JoinOrNewGame(id string, playerName string) (game.Game, game.Player, <-chan *game.State, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil, game.Player{}, nil, errors.New("id must not be empty")
	}

	playerName = strings.TrimSpace(playerName)
	if playerName == "" {
		playerName = "Unnamed Player"
	}

	game_, err := (func(s *serverState) (game.Game, error) {
		s.mutex.Lock()
		defer s.mutex.Unlock()

		existing, ok := s.games[id]
		if ok {
			return existing, nil
		}

		game_, err := game.NewGame(id)
		if err != nil {
			return nil, err
		}
		s.games[id] = game_
		return game_, nil
	})(s)
	if err != nil {
		return nil, game.Player{}, nil, err
	}

	game_.Lock()
	defer game_.Unlock()

	player, stateChan, err := game_.AddPlayer(playerName)
	if err != nil {
		return nil, player, nil, err
	}
	game_.BroadcastState()

	return game_, player, stateChan, nil
}

func (s *serverState) EmptyGames() chan string {
	return s.emptyGames
}

func (s *serverState) StartCleanup() {
	// TODO: wait a bit to be sure the game is empty, like rust implementation
	go func() {
		for id := range s.emptyGames {
			go func(id string) {
				log.Println("deleting game in 1 minute:", id)
				time.Sleep(1 * time.Minute)
				if err := s.deleteGame(id); err != nil {
					log.Println("error deleting game:", err)
				}
				log.Println("deleted game:", id)
			}(id)
		}
	}()
}

func (s *serverState) deleteGame(id string) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	_, ok := s.games[id]
	if !ok {
		return errors.New("game not found")
	}

	delete(s.games, id)
	return nil
}
