.PHONY: build-client build-server build \
	debug-client debug-server debug \
	check-client check-server check \
	run-client run-server

build-client:
	odin build client -out:build/client.exe

build-server:
	odin build server -out:build/server.exe

build: build-client build-server

debug-client:
	odin build client -out:build/client_debug.exe -debug

debug-server:
	odin build server -out:build/server_debug.exe -debug

debug: debug-client debug-server

check-client:
	odin check client

check-server:
	odin check server

check: check-client check-server

run-client:
	odin run client -out:build/client.exe

run-server:
	odin run server -out:build/server.exe
