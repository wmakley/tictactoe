SOURCE := go.mod go.sum $(shell find . -name *.go)

go-backend: $(SOURCE)
	go build .

clean:
	rm go-backend

dev:
	go run .

deploy:
	fly deploy

.PHONY: clean dev deploy
