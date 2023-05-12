release:
	cargo build --release

dev:
	RUST_LOG="info,tictactoe_rs=trace,tower_http=trace" cargo run

deploy:
	fly deploy

docker-image:
	docker build -t tictactoe-rs:latest .

.PHONY: release deploy docker-image
