.PHONY: default debug run check

default:
	odin build src -out:build/teluria.exe

debug:
	odin build src -out:build/teluria_debug.exe -debug

run:
	odin run src

check:
	odin check src
