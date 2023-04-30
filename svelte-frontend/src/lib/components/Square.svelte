<script lang="ts">
    export let value: string;
    export let disabled: boolean;
    export let onClick: () => void;
</script>

<div
    class="game-square {disabled
        ? 'disabled'
        : 'enabled'} {value.toLowerCase()}"
    on:click={disabled ? null : onClick}
    on:keyup={disabled
        ? null
        : (e) => {
              if (e.key === "Enter") {
                  onClick();
              }
          }}
>
    {value}
</div>
