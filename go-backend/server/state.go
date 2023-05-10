package server

import (
	"errors"
	"go-backend/game"
	"log"
	"strings"
	"sync"
)

type State interface {
	JoinOrNewGame(id string, playerName string) (game.Game, game.Player, error)
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

func (s *serverState) JoinOrNewGame(id string, playerName string) (game.Game, game.Player, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil, game.Player{}, errors.New("id must not be empty")
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
		return nil, game.Player{}, err
	}

	game_.Lock()
	defer game_.Unlock()

	player, err := game_.AddPlayer(playerName)
	if err != nil {
		return nil, player, err
	}
	game_.BroadcastState()

	return game_, player, nil
}

func (s *serverState) EmptyGames() chan string {
	return s.emptyGames
}

func (s *serverState) StartCleanup() {
	// TODO: wait a bit to be sure the game is empty, like rust implementation
	go func() {
		for id := range s.emptyGames {
			log.Println("deleting game:", id)
			if err := s.deleteGame(id); err != nil {
				log.Println("error deleting game:", err)
			}
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
