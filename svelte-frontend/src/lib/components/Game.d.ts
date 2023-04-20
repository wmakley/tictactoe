interface GameState {
    turn: Team;
    winner: "Draw" | { Win: Team } | null;
    players: Player[];
    board: Square[];
    chat: ChatMessage[];
}

interface Player {
    id: PlayerID;
    team: Team;
    name: string;
    wins: number;
}

type PlayerID = number;

type Team = "X" | "O";
type Square = " " | "X" | "O";

interface ChatMessage {
    id: number;
    source: ChatMessageSource | System;
    text: string;
}

type System = "System";

type ChatMessageSource = PlayerSource | System;
interface PlayerSource {
    Player: number;
}
