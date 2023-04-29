export interface Backend {
    slug: string;
    label: string;
    url: string;
}

export const backends: Backend[] = [
    { slug: "localhost", label: "Localhost", url: "localhost:3000" },
    { slug: "rust", label: "Rust", url: "tictactoe-rust-backend.fly.dev" },
    { slug: "go", label: "Go", url: "tictactoe-go-backend.fly.dev" },
];

export function findBackend(slug: string) {
    return backends.find((b) => b.slug === slug);
}
