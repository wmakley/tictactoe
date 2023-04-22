package game

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
)

type Game interface {
	Id() string
	State() *State
	StateChanges() chan *State
	AddPlayer(name string) (Player, error)
	RemovePlayer(id PlayerId) error
	IsEmpty() bool
	HandleMsg(playerId PlayerId, msg FromBrowser) error
	BroadcastState()
	sync.Locker
}

func NewGame(id string) (Game, error) {
	return &game{
		id:           id,
		state:        newState(),
		stateChanges: make(chan *State, 2),
	}, nil
}

type game struct {
	id           string
	state        *State
	stateChanges chan *State
	mutex        sync.Mutex
}

func (g *game) Id() string {
	return g.id
}

func (g *game) State() *State {
	return g.state
}

func (g *game) StateChanges() chan *State {
	return g.stateChanges
}

func (g *game) Lock() {
	g.mutex.Lock()
}

func (g *game) Unlock() {
	g.mutex.Unlock()
}

func (g *game) AddPlayer(name string) (Player, error) {
	if len(g.state.Players) >= 2 {
		return Player{}, errors.New("game is full")
	}

	var id PlayerId
	var team Team

	if len(g.state.Players) == 0 {
		id = 1
		team = TeamX
	} else {
		otherPlayer := g.state.Players[len(g.state.Players)-1]
		id = otherPlayer.Id + 1
		team = TeamO
	}

	player := Player{
		Id:   id,
		Name: name,
		Team: team,
	}
	g.state.Players = append(g.state.Players, player)
	g.addChatMessage(systemSource(), player.String()+" has joined the game!")
	return player, nil
}

func (g *game) RemovePlayer(id PlayerId) error {
	index, err := g.getPlayerIndex(id)
	if err != nil {
		return err
	}

	player := g.state.Players[index]
	// TODO: not sure if this works
	g.state.Players = append(g.state.Players[:index], g.state.Players[index+1:]...)
	g.addChatMessage(systemSource(), player.String()+" has left the game!")
	g.BroadcastState()
	return nil
}

func (g *game) IsEmpty() bool {
	return len(g.state.Players) == 0
}

func (g *game) HandleMsg(playerId PlayerId, msg FromBrowser) error {
	log.Println("handling message from player", playerId, ":", msg)
	switch msg.MsgType {
	case MsgTypeChat:
		chatMsg := strings.TrimSpace(msg.Text)
		if chatMsg == "" {
			return errors.New("chat message must not be empty")
		}
		if len(chatMsg) > 500 {
			return errors.New("chat message must not be longer than 500 characters")
		}
		g.addChatMessage(playerSource(playerId), msg.Text)
		return nil
	case MsgTypeMove:
		return g.takeTurn(playerId, msg.Space)
	case MsgTypeChangeName:
		newName := strings.TrimSpace(msg.Text)
		if newName == "" {
			newName = "Unnamed Player"
		} else if len(newName) > 32 {
			newName = newName[:32]
		}
		if err := g.updatePlayerName(playerId, newName); err != nil {
			return err
		}
		g.addChatMessage(playerSource(playerId), fmt.Sprintf("Now my name is %s!", newName))
		return nil
	case MsgTypeRematch:
		if !g.state.Winner.Done {
			return errors.New("game is not over")
		}
		g.addChatMessage(playerSource(playerId), "Rematch!")
		g.addChatMessage(systemSource(), "Players have swapped sides.")
		g.reset()
		g.swapTeams()
		return nil
	default:
		return errors.New("unknown message type")
	}
}

func (g *game) takeTurn(playerId PlayerId, space int) error {
	if len(g.state.Players) == 0 {
		return errors.New("not enough players")
	}
	if g.state.Winner.Done {
		return errors.New("game is over")
	}

	playerIdx, err := g.getPlayerIndex(playerId)
	if err != nil {
		return err
	}

	player := g.state.Players[playerIdx]
	team := player.Team

	if g.state.Turn != team {
		return errors.New("not your turn")
	}

	if space < 0 || space >= len(g.state.Board) || g.state.Board[space] != TeamNone {
		return errors.New("invalid move")
	}

	g.state.Board[space] = team
	if g.state.Turn == TeamX {
		g.state.Turn = TeamO
	} else {
		g.state.Turn = TeamX
	}

	g.addChatMessage(playerSource(playerId),
		fmt.Sprintf("Played %s at (%d, %d).", string(team), space%3+1, space/3+1))

	if winner := g.checkWin(); winner != TeamNone {
		g.state.Winner = EndState{
			Done:   true,
			Winner: winner,
			Draw:   false,
		}
		g.addChatMessage(systemSource(), fmt.Sprintf("%s wins!", player.String()))

	} else if g.checkDraw() {
		g.state.Winner = EndState{
			Done:   true,
			Winner: TeamNone,
			Draw:   true,
		}
		g.addChatMessage(systemSource(), "It's a draw!")
	}

	return nil
}

var winningCombos [][]int = [][]int{
	{0, 1, 2},
	{3, 4, 5},
	{6, 7, 8},
	{0, 3, 6},
	{1, 4, 7},
	{2, 5, 8},
	{0, 4, 8},
	{2, 4, 6},
}

func (g *game) checkWin() Team {
	winner := TeamNone
	for _, combo := range winningCombos {
		if g.state.Board[combo[0]] != TeamNone &&
			g.state.Board[combo[0]] == g.state.Board[combo[1]] &&
			g.state.Board[combo[1]] == g.state.Board[combo[2]] {
			winner = g.state.Board[combo[0]]
			break
		}
	}
	return winner
}

func (g *game) checkDraw() bool {
	for _, space := range g.state.Board {
		if space == TeamNone {
			return false
		}
	}
	return true
}

func (g *game) updatePlayerName(playerId PlayerId, newName string) error {
	playerIdx, err := g.getPlayerIndex(playerId)
	if err != nil {
		return err
	}
	g.state.Players[playerIdx].Name = newName
	g.addChatMessage(playerSource(playerId), "Changed name to "+newName)
	return nil
}

func (g *game) reset() {
	for i := 0; i < len(g.state.Board); i++ {
		g.state.Board[i] = TeamNone
	}
	g.state.Turn = TeamX
	g.state.Winner = EndState{
		Done:   false,
		Winner: TeamNone,
		Draw:   false,
	}
}

func (g *game) swapTeams() {
	for i := 0; i < len(g.state.Players); i++ {
		player := &g.state.Players[i]
		if player.Team == TeamX {
			player.Team = TeamO
		} else {
			player.Team = TeamX
		}
	}
}

func (g *game) BroadcastState() {
	if len(g.state.Players) == 0 {
		return
	}
	// broadcast once for each player
	stateCopy := g.state.Clone()
	for i := 0; i < len(g.state.Players); i++ {
		select {
		case g.stateChanges <- stateCopy:
			// sent
		default:
			// channel is full, drop the message
		}
	}
}

func (g *game) addChatMessage(source ChatMessageSource, text string) {
	g.state.Chat = append(g.state.Chat, ChatMessage{
		Id:     len(g.state.Chat),
		Source: source,
		Text:   text,
	})
}

func (g *game) getPlayerIndex(id PlayerId) (int, error) {
	for i, player := range g.state.Players {
		if player.Id == id {
			return i, nil
		}
	}
	return -1, errors.New("player not found")
}

func (g *game) getPlayerIndexByTeam(team Team) (int, error) {
	for i, player := range g.state.Players {
		if player.Team == team {
			return i, nil
		}
	}
	return -1, errors.New("player not found")
}

func newState() *State {
	return &State{
		Turn:    TeamX,
		Winner:  EndState{},
		Players: []Player{},
		Board:   []Team{TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone},
		Chat:    []ChatMessage{},
	}
}

type State struct {
	Turn    Team          `json:"turn"`
	Winner  EndState      `json:"winner"`
	Players []Player      `json:"players"`
	Board   []Team        `json:"board"`
	Chat    []ChatMessage `json:"chat"`
}

type Team byte

const TeamNone Team = ' '
const TeamX Team = 'X'
const TeamO Team = 'O'

func (t *Team) MarshalJSON() ([]byte, error) {
	return json.Marshal(string(*t))
}

func (t *Team) UnmarshalJSON(data []byte) error {
	var s string
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}
	if len(s) != 1 {
		return errors.New("invalid team")
	}
	switch s[0] {
	case 'X':
		*t = TeamX
	case 'O':
		*t = TeamO
	case ' ':
		*t = TeamNone
	default:
		return errors.New("invalid team")
	}
	return nil
}

func (s State) String() string {
	return fmt.Sprintf("State{Turn: %s, Winner: %s, Players: %s, Board: %s, Chat: %+v}",
		string(s.Turn), s.Winner.String(), s.Players, s.Board, s.Chat)
}

func (s State) Clone() *State {
	return &State{
		Turn:    s.Turn,
		Winner:  s.Winner.Clone(),
		Players: s.clonePlayers(),
		Board:   s.cloneBoard(),
		Chat:    s.cloneChat(),
	}
}

func (s State) clonePlayers() []Player {
	players := make([]Player, len(s.Players))
	for i, player := range s.Players {
		players[i] = player.Clone()
	}
	return players
}

func (s State) cloneBoard() []Team {
	board := make([]Team, len(s.Board))
	copy(board, s.Board)
	return board
}

func (s State) cloneChat() []ChatMessage {
	chat := make([]ChatMessage, len(s.Chat))
	for i, message := range s.Chat {
		chat[i] = message.Clone()
	}
	return chat
}

type EndState struct {
	Done   bool
	Winner Team
	Draw   bool
}

func (e EndState) Clone() EndState {
	return EndState{
		Done:   e.Done,
		Winner: e.Winner,
		Draw:   e.Draw,
	}
}

func (e EndState) String() string {
	return fmt.Sprintf("EndState{Done: %t, Winner: %s, Draw: %t}", e.Done, string(e.Winner), e.Draw)
}

func (e EndState) MarshalJSON() ([]byte, error) {
	if !e.Done {
		return []byte(`null`), nil
	}
	if e.Draw {
		return []byte(`"Draw"`), nil
	}
	return []byte(`{"Win":"` + string(e.Winner) + `"}`), nil
}

type Player struct {
	Id   PlayerId `json:"id"`
	Team Team     `json:"team"`
	Name string   `json:"name"`
	Wins int32    `json:"wins"`
}

type PlayerId int32

func (p Player) String() string {
	return fmt.Sprintf("%s (%s)", p.Name, string(p.Team))
}

func (p Player) Clone() Player {
	return Player{
		Id:   p.Id,
		Team: p.Team,
		Name: p.Name,
		Wins: p.Wins,
	}
}

type ChatMessage struct {
	Id     int               `json:"id"`
	Source ChatMessageSource `json:"source"`
	Text   string            `json:"text"`
}

func (c ChatMessage) Clone() ChatMessage {
	return ChatMessage{
		Id:     c.Id,
		Source: c.Source,
		Text:   c.Text,
	}
}

type ChatMessageSource struct {
	SourceType int
	PlayerId   PlayerId
}

const SourceTypeSystem = 0
const SourceTypePlayer = 1

func playerSource(playerId PlayerId) ChatMessageSource {
	return ChatMessageSource{
		SourceType: SourceTypePlayer,
		PlayerId:   playerId,
	}
}

func systemSource() ChatMessageSource {
	return ChatMessageSource{
		SourceType: SourceTypeSystem,
	}
}

func (c ChatMessageSource) MarshalJSON() ([]byte, error) {
	if c.SourceType == SourceTypeSystem {
		return []byte(`"System"`), nil
	}
	return []byte(fmt.Sprintf(`{"Player":%d}`, c.PlayerId)), nil
}

type FromBrowser struct {
	MsgType IncomingMsgType
	Text    string
	Space   int
}

type IncomingMsgType int

const (
	MsgTypeMove = iota
	MsgTypeChat
	MsgTypeChangeName
	MsgTypeRematch
)

var (
	ErrInvalidMessage = errors.New("invalid message")
)

func (m *FromBrowser) UnmarshalJSON(data []byte) error {
	//log.Println("data:", string(data))

	var stringMsg string
	if err := json.Unmarshal(data, &stringMsg); err == nil {
		if stringMsg == "Rematch" {
			m.MsgType = MsgTypeRematch
			m.Space = 0
			m.Text = ""
			return nil
		}
		return ErrInvalidMessage
	}

	var rawMsg map[string]interface{}
	if err := json.Unmarshal(data, &rawMsg); err != nil {
		return ErrInvalidMessage
	}

	chat, ok := rawMsg["ChatMsg"]
	if ok {
		m.MsgType = MsgTypeChat
		data, ok := chat.(map[string]interface{})
		if !ok {
			return ErrInvalidMessage
		}
		text, ok := data["text"]
		if !ok {
			return ErrInvalidMessage
		}
		textString, ok := text.(string)
		if !ok {
			return ErrInvalidMessage
		}
		m.Text = textString
		m.Space = 0
		return nil
	}

	move, ok := rawMsg["Move"]
	if ok {
		m.MsgType = MsgTypeMove
		data, ok := move.(map[string]interface{})
		if !ok {
			return ErrInvalidMessage
		}
		space, ok := data["space"]
		if !ok {
			return ErrInvalidMessage
		}
		spaceFloat, ok := space.(float64)
		if !ok {
			return ErrInvalidMessage
		}
		m.Space = int(spaceFloat)
		m.Text = ""
		return nil
	}

	changeName, ok := rawMsg["ChangeName"]
	if ok {
		m.MsgType = MsgTypeChangeName
		data, ok := changeName.(map[string]interface{})
		if !ok {
			return ErrInvalidMessage
		}
		name, ok := data["new_name"]
		if !ok {
			return ErrInvalidMessage
		}
		nameString, ok := name.(string)
		if !ok {
			return ErrInvalidMessage
		}
		m.Text = nameString
		m.Space = 0
		return nil
	}

	return ErrInvalidMessage
}

type JoinedGameMsg struct {
	JoinedGame JoinedGameInner `json:"JoinedGame"`
}

type JoinedGameInner struct {
	Token    string   `json:"token"`
	PlayerId PlayerId `json:"player_id"`
	State    *State   `json:"state"`
}

type GameStateMsg struct {
	GameState *State `json:"GameState"`
}

type ErrorMsg struct {
	Error string `json:"Error"`
}

func NewJoinedGameMsg(token string, playerId PlayerId, state *State) JoinedGameMsg {
	return JoinedGameMsg{
		JoinedGame: struct {
			Token    string   `json:"token"`
			PlayerId PlayerId `json:"player_id"`
			State    *State   `json:"state"`
		}{
			Token:    token,
			PlayerId: playerId,
			State:    state,
		},
	}
}

func NewGameStateMsg(state *State) GameStateMsg {
	return GameStateMsg{
		GameState: state,
	}
}

func NewErrorMsg(errorMsg string) ErrorMsg {
	return ErrorMsg{
		Error: errorMsg,
	}
}
