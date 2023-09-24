.PHONY: default debug

default:
	odin build src -out:build/teluria.exe

debug:
	odin build src -out:build/teluria_debug.exe -debug
