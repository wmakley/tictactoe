<script lang="ts">
    import Game from "../lib/components/Game.svelte";

    const backends = [
        ["Localhost", "localhost:3000"],
        ["Rust", "tictactoe-rust-backend.fly.dev"],
        ["Go", "tictactoe-go-backend.fly.dev"],
    ];
    let backendUrl = "tictactoe-rust-backend.fly.dev";
</script>

<div class="container">
    <h1>Tic Tac Toe</h1>
    <form>
        <label for="backend">Backend</label>
        <select
            id="backend"
            on:change={(event) => (backendUrl = event.currentTarget.value)}
        >
            {#each backends as [name, url]}
                <option value={url} selected={url === backendUrl}>{name}</option
                >
            {/each}
        </select>
    </form>
    <Game {backendUrl} />
    <footer>
        <p>
            Copyright &copy; 2023 William Manahan-Makley |
            <a href="https://github.com/wmakley/tictactoe">Source Code</a>
        </p>
    </footer>
</div>
