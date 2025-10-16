-include .env

.PHONY: all build test

build: 
	forge build -vvvv

test: 
	forge test -vvvv