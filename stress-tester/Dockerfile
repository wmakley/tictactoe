# == builder ==
FROM rust:slim-bullseye as builder
WORKDIR /usr/src/myapp

RUN apt update && \
    apt install -y openssl libssl-dev \
    && rm -rf /var/lib/apt/lists/*

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

# == production image ==
FROM debian:bullseye-slim

RUN apt update && \
    apt install -y ca-certificates openssl \
    && rm -rf /var/lib/apt/lists/*
RUN update-ca-certificates

COPY --from=builder /usr/local/cargo/bin/stress-tester /usr/local/bin/stress-tester

WORKDIR /app

ENTRYPOINT ["stress-tester"]
