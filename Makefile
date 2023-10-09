.PHONY: build-client build-server build-all \
	debug-client debug-server debug-all \
	check-client check-server check-all \
	release-client release-server release-all \
	run-client run-server

GOPTIONS = -vet-unused -vet-shadowing -vet-style -vet-semicolon
ROPTIONS = -o:speed

release-client:
	odin build client -out:build/client_release.exe $(GOPTIONS) $(ROPTIONS)

release-server:
	odin build server -out:build/server_release.exe $(GOPTIONS) $(ROPTIONS)

release-all: release-client release-server

build-client:
	odin build client -out:build/client.exe $(GOPTIONS)

build-server:
	odin build server -out:build/server.exe $(GOPTIONS)

build-all: build-client build-server

debug-client:
	odin build client -out:build/client_debug.exe -debug $(GOPTIONS)

debug-server:
	odin build server -out:build/server_debug.exe -debug $(GOPTIONS)

debug-all: debug-client debug-server

check-client:
	odin check client $(GOPTIONS)

check-server:
	odin check server $(GOPTIONS)

check-all: check-client check-server

run-client:
	odin run client -out:build/client.exe $(GOPTIONS)

run-server:
	odin run server -out:build/server.exe $(GOPTIONS)
