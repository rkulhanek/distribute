DFLAGS=-g -O -L-lc
.PHONY: all clean

all: client server

clean:
	rm client server client.o server.o

client: client.d util.d
	dmd $(DFLAGS) $^

server: server.d util.d
	dmd $(DFLAGS) $^

