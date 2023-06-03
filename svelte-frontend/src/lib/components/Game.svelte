<script lang="ts">
    export let backendUrl = "";

    import { onMount, afterUpdate } from "svelte";
    import Square from "./Square.svelte";

    // https://natclark.com/tutorials/svelte-get-current-url/
    let url: URL | null = null;
    let joinToken = "";

    onMount(() => {
        url = new URL(window.location.href);

        playerName = localStorage.getItem("playerName") || "";
        console.debug("playerName", playerName);
        if (playerName.length > 32) {
            console.error("playerName too long");
            playerName = playerName.slice(0, 32);
        }

        joinToken = url.searchParams.get("token") || "";
        if (joinToken) {
            if (joinToken.length > 32) {
                console.error("joinToken too long");
                joinToken = "";
                return;
            }
            joinGame();
        }
    });
    function socketUrl(): string {
        if (!url) {
            return "";
        }
        return `${backendUrl}/ws`;
    }

    afterUpdate(() => {
        const chat = document.getElementById("chat-messages");
        if (chat) {
            chat.scrollTop = chat.scrollHeight;
        }
    });

    let playerName = "";
    let inGame = false;
    let enoughPlayers = false;
    // ID should be constant across rematches
    let myPlayerId: PlayerID = -1;
    let me: Player = {
        id: 0,
        team: "X",
        name: "",
        wins: 0,
    };

    let gameState: GameState = {
        turn: "X",
        winner: null,
        players: [],
        board: [" ", " ", " ", " ", " ", " ", " ", " ", " "],
        chat: [],
    };
    function getPlayer(gameState: GameState, id: PlayerID): Player | undefined {
        return gameState.players.find((p) => p.id === id);
    }

    /**
     * Map over the raw chat messages, replacing the player ID with the player.
     */
    function getChatMessagesWithPlayers(
        gameState: GameState
    ): [number, Player | string, string][] {
        return gameState.chat.map(({ id, source, text }) => {
            return [
                id,
                source === "System"
                    ? "System"
                    : getPlayer(gameState, source.Player) || "Unknown",
                text,
            ];
        });
    }

    let ws: WebSocket | null = null;

    function joinGame(): void {
        if (inGame) {
            return;
        }
        if (!socketUrl) {
            throw new Error("socketUrl not set");
        }

        console.log(
            "Joining game with player name:",
            playerName,
            "and join token:",
            joinToken
        );

        const url = new URL(socketUrl());
        url.searchParams.set("token", joinToken);
        url.searchParams.set("name", playerName);

        ws = new WebSocket(url.href);

        ws.onopen = () => {
            chatMessage = "";
            inGame = true;
        };

        ws.onmessage = (rawMsg) => {
            console.debug("Got Msg From Server:", rawMsg);
            const json = JSON.parse(rawMsg.data);
            console.debug("json", json);
            const type = Object.keys(json)[0].toString();
            const data = json[type];
            // console.debug("type", type, "data", data);

            if (type === "JoinedGame") {
                const { token, player_id, state } = data;
                joinToken = token as string;
                gameState = state as GameState;
                myPlayerId = player_id as number;
                me = getPlayer(gameState, myPlayerId)!;
                enoughPlayers = gameState.players.length === 2;
                window.history.replaceState(
                    {},
                    document.title,
                    `?token=${encodeURIComponent(joinToken)}`
                );
            } else if (type === "GameState") {
                gameState = data as GameState;
                enoughPlayers = gameState.players.length === 2;
                me = getPlayer(gameState, myPlayerId)!;
            } else if (type === "Error") {
                console.error("Error from server", data);
                window.alert(data);
                ws?.close();
            } else {
                console.error("Unknown message type", type);
            }
        };

        ws.onclose = () => {
            inGame = false;
            console.log("disconnected by server");
            ws = null;
            (
                document.getElementById("join-token") as HTMLInputElement
            )?.select();
            // get rid of token in url to prevent accidental linking or inability to refresh
            const url = new URL(window.location.href);
            url.searchParams.delete("token");
            window.history.replaceState({}, document.title, url.href);
        };

        ws.onerror = (err) => {
            console.error("error", err);
        };
    }

    function leaveGame(): void {
        console.log("Leaving game");
        if (ws) {
            ws.close();
        }
    }

    let chatMessage = "";
    function isChatMessageValid(chatMessage: string): boolean {
        const trimmed = (chatMessage || "").replace(/^\s+|\s+$/gm, "");
        return trimmed.length > 0 && trimmed.length <= 500;
    }

    function sendChatMessage(): void {
        if (!ws) {
            return;
        }
        if (!isChatMessageValid(chatMessage)) {
            return;
        }
        ws.send(JSON.stringify({ ChatMsg: { text: chatMessage } }));
        chatMessage = "";
    }

    function changeName(): void {
        localStorage.setItem("playerName", playerName);

        if (!playerName) {
            return;
        }
        if (!ws || !inGame) {
            return;
        }

        ws.send(JSON.stringify({ ChangeName: { new_name: playerName } }));
    }

    function sendMove(space: number): void {
        if (!ws) {
            return;
        }
        if (!enoughPlayers) {
            console.warn("not enough players to play");
            return;
        }
        if (gameState.turn !== me.team) {
            console.warn("not my turn");
            return;
        }
        if (gameState.winner) {
            console.warn("game is over");
            return;
        }
        ws.send(JSON.stringify({ Move: { space } }));
    }

    function rematch(): void {
        if (!ws) {
            return;
        }
        if (!gameState.winner) {
            console.warn("game is not over");
            return;
        }
        ws.send(JSON.stringify("Rematch"));
    }
</script>

<div id="menu">
    <form id="join-game-form" on:submit|preventDefault={joinGame}>
        <div class="row">
            <div class="column">
                <label for="player-name">Player Name</label>
                <input
                    type="text"
                    id="player-name"
                    name="name"
                    placeholder="Player Name"
                    maxlength="32"
                    bind:value={playerName}
                    on:change={changeName}
                />
            </div>
            <div class="column">
                <label for="join-token"
                    >{inGame
                        ? "Code For Others to Join You"
                        : "Game Name"}</label
                >
                <input
                    type="text"
                    id="join-token"
                    name="token"
                    placeholder="Game Name (leave blank for random)"
                    maxlength="32"
                    readonly={inGame}
                    on:click={(e) => {
                        if (inGame) {
                            e.currentTarget.select();
                            navigator.clipboard.writeText(joinToken);
                        }
                    }}
                    bind:value={joinToken}
                />
            </div>
            {#if inGame}
                <div class="column">
                    <button
                        type="button"
                        on:click={leaveGame}
                        class="horizontal-submit"
                    >
                        Leave Game
                    </button>
                </div>
            {:else}
                <div class="column">
                    <button type="submit" class="horizontal-submit">
                        Join or Start Game
                    </button>
                </div>
            {/if}
        </div>
    </form>
</div>

<div class={inGame ? "" : "hidden"}>
    <div class="status">
        {#if !enoughPlayers}
            Waiting for opponent...
        {:else if gameState.winner}
            {#if gameState.winner === "Draw"}
                Draw!
            {:else if gameState.winner.Win === me.team}
                You won!
            {:else}
                You lost!
            {/if}
        {:else if gameState.turn === me.team}
            Your turn
        {:else}
            Opponent's turn
        {/if}
    </div>

    <div class="row">
        <div class="column">
            <div class="game-board">
                {#each gameState.board as square, i}
                    <Square
                        value={square}
                        disabled={!enoughPlayers ||
                            gameState.winner !== null ||
                            gameState.turn !== me.team ||
                            square !== " "}
                        onClick={() => sendMove(i)}
                    />
                {/each}
            </div>
        </div>

        <div class="column">
            <div id="chat">
                <h2>Chat</h2>
                <div id="chat-messages" class="chat-messages">
                    {#each getChatMessagesWithPlayers(gameState) as [id, source, text]}
                        <div class="chat-message" id={`chat-message-${id}`}>
                            {#if typeof source === "string"}
                                <span class="chat-message-server">
                                    {source === "System"
                                        ? "Server:"
                                        : source + ":"}
                                </span>
                            {:else}
                                <span class="chat-message-player">
                                    {source.name} ({source.wins}):
                                </span>
                            {/if}
                            <span class="chat-message-text">{text}</span>
                        </div>
                    {/each}
                </div>
                <form on:submit|preventDefault={sendChatMessage}>
                    <div class="row">
                        <div class="column">
                            <input
                                type="text"
                                id="chat-msg"
                                name="msg"
                                placeholder="Message"
                                bind:value={chatMessage}
                            />
                        </div>
                        <div class="column">
                            <input
                                type="submit"
                                value="Send"
                                disabled={!inGame ||
                                    !isChatMessageValid(chatMessage)}
                            />
                            {#if gameState.winner}
                                <input
                                    type="button"
                                    on:click={rematch}
                                    value="Rematch!"
                                />
                            {/if}
                        </div>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>
