<script lang="ts">
    import type { LayoutData } from "./$types";
    import { goto } from "$app/navigation";

    export let data: LayoutData;

    function onBackendChange(slug: string) {
        goto(`/backend/${slug}`, { replaceState: false });
    }
</script>

<div class="container">
    <h1>Tic Tac Toe</h1>
    <form>
        <label for="backend">Backend</label>
        <select
            id="backend"
            on:change={(event) => onBackendChange(event.currentTarget.value)}
        >
            {#each data.backends as { label, slug }}
                <option value={slug} selected={slug === data.slug}
                    >{label}</option
                >
            {/each}
        </select>
    </form>

    <slot />

    <footer>
        <p>
            Copyright &copy; 2023 William Manahan-Makley |
            <a href="https://github.com/wmakley/tictactoe">Source Code</a>
        </p>
    </footer>
</div>
