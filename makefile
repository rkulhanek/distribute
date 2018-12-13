DFLAGS=-g -O -L-lc
.PHONY: all

all: client server

client: client.d util.d
	dmd $(DFLAGS) $^

server: server.d util.d
	dmd $(DFLAGS) $^

