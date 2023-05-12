FROM rust:slim-bullseye as builder
WORKDIR /usr/src/myapp

# cache dependencies
COPY Cargo.toml .
COPY Cargo.lock .
RUN echo "fn main() {}" > dummy.rs
RUN sed -i 's#src/main.rs#dummy.rs#' Cargo.toml
RUN cargo build --release
RUN sed -i 's#dummy.rs#src/main.rs#' Cargo.toml

# the actual build
COPY . .
RUN cargo install --path .

FROM debian:bullseye-slim
COPY --from=builder /usr/local/cargo/bin/tictactoe-rs /usr/local/bin/tictactoe-rs
WORKDIR /app
CMD ["tictactoe-rs"]
EXPOSE 3000

ENV RUST_LOG "info,tictactoe_rs=info,tower_http=info"
ENV FRONTEND_URL "https://svelte-frontend-mu.vercel.app/"
