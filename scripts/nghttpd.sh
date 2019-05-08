#!/bin/bash

SCRIPT=$0
PID=$$
OPTS=`getopt -o vhd: --long max-concurrent-streams:,header-table-size:,window-bits:,max-frame-size:,max-header-list-size:,help -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# Default directories
BIN=${BIN:-"./bin"}

MAX_CONCURRENT_STREAMS=1
HEADER_TABLE_SIZE=4096
WINDOW_BITS=16
MAX_FRAME_SIZE=16384

while true; do
  case "$1" in
    --max-concurrent-streams)   MAX_CONCURRENT_STREAMS=$2; shift; shift ;;
    --header-table-size)        HEADER_TABLE_SIZE=$2; shift; shift ;;
    --window-bits)              WINDOW_BITS=$2; shift; shift ;;
    --max-frame-size)           MAX_FRAME_SIZE=$2; shift; shift ;;
    --max-header-list-size)     MAX_HEADER_LIST_SIZE=$2; shift; shift ;;
    -h | --help )               HELP=true; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

usage() {
    echo "Usage $SCRIPT [options] <port> [<private key> <cert>]"
    echo "Options:"
    echo "--max-concurrent-streams=<n>"
    echo "--header-table-size=<size>"
    echo "--window-bits=<n>"
    echo "--max-frame-size=<size>"
    echo "--max-header-list-size=<size>"
}

nghttpd() {
	CMD="$BIN/nghttpd"

	if [ -n "$MAX_CONCURRENT_STREAMS" ]; then
        CMD="$CMD --max-concurrent-streams=$MAX_CONCURRENT_STREAMS"
    fi

	if [ -n "$HEADER_TABLE_SIZE" ]; then
        CMD="$CMD --header-table-size=$HEADER_TABLE_SIZE --encoder-header-table-size=$HEADER_TABLE_SIZE"
    fi

	if [ -n "$WINDOW_BITS" ]; then
        CMD="$CMD --window-bits=$WINDOW_BITS --connection-window-bits=$WINDOW_BITS"
    fi

	if [ -n "$MAX_FRAME_SIZE" ]; then
        CMD="$CMD --max-frame-size=$MAX_FRAME_SIZE"
    fi

	if [ -n "$MAX_HEADER_LIST_SIZE" ]; then
        CMD="$CMD --max-header-list-size=$MAX_HEADER_LIST_SIZE"
    fi

    exec $CMD $* 1>&2
}

summary() {
    END_TIME=$(date +%s.%N)

    echo "start-time: $START_TIME"
    echo "end-time: $END_TIME"
    echo "max-concurrent-streams: $MAX_CONCURRENT_STREAMS"
    echo "header-table-size: $HEADER_TABLE_SIZE"
    echo "window-bits: $WINDOW_BITS"
    echo "max-frame-size: $MAX_FRAME_SIZE"
    echo "max-header-list-size: $MAX_HEADER_LIST_SIZE"
    echo ""
    printf "%-22s %-6s %-6s\n" "timestamp" "cpu" "mem"
    cat /tmp/$PID-nghttpd.log
}

sigterm() {
    kill -- $TOP_PID
    kill -- $WAIT_PID
    summary
}

# Catch term and interrupt signal
trap sigterm SIGTERM
trap summary SIGINT

# Execute server and store data
START_TIME=$(date +%s.%N)
top -b -d 0.01 > >(grep  "nghttpd$" | awk '{printf "%-2s %-6s %-6s\n", system("echo -n `date +%s.%N`"), $9, $10}' > /tmp/$PID-nghttpd.log) &

TOP_PID=$!
nghttpd $* &
WAIT_PID=$!

wait
