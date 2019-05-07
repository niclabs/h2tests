#!/bin/bash

SCRIPT=$0
PID=$$
OPTS=`getopt -o hn:c: --long header-table-size,window-bits,max-frame-size,max-header-list-size,help: -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# Default directories
BIN=${BIN:-"./bin"}

#MAX_CONCURRENT_STREAMS=1
#HEADER_TABLE_SIZE=4096
#WINDOW_BITS=16
#MAX_FRAME_SIZE=16384

while true; do
  case "$1" in
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

h2load() {
	CMD="$BIN/h2load"

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

    exec $CMD $*
}

summary() {
    END_TIME=$(date +%s.%N)

    echo "start-time: $START_TIME"
    echo "end-time: $END_TIME"
    echo "header-table-size: $HEADER_TABLE_SIZE"
    echo "window-bits: $WINDOW_BITS"
    echo "max-frame-size: $MAX_FRAME_SIZE"
    echo "max-header-list-size: $MAX_HEADER_LIST_SIZE"
    echo -e "columns: time\tcpu\tmem"

    awk -f ./scripts/process_h2load_output.awk <&0
}

# Execute server and store data
START_TIME=$(date +%s.%N)
h2load $* | summary
