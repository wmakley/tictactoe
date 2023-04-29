<script lang="ts">
    import type { PageData } from "./$types";
    import Game from "../../../lib/components/Game.svelte";

    export let data: PageData;
</script>

<Game backendUrl={data.backend?.url} />
