#!/bin/bash

# Example program. If this is used as the command, the server will collect
# the line counts of each input file

if [ 0 -eq $# ]; then
	exit 0
fi

wc -l "$1"
