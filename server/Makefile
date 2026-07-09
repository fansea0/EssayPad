.PHONY: run build test tidy

PORT ?= 18888

run:
	ESSAYPAD_PORT=$(PORT) go run .

build:
	go build -o bin/essaypad .

test:
	go test ./...

tidy:
	go mod tidy
