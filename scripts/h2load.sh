#!/bin/bash -e

SCRIPT=$0
PID=$$
OPTS=`getopt -o hvn:c:o: --long output:,max-concurrent-streams:,header-table-size:,window-bits:,max-frame-size:,max-header-list-size:,help -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# Default directories
BIN=${BIN:-"./bin"}
SCRIPTS=${SCRIPTS:-"./scripts"}

# Update path with local bin dir
PATH=$PATH:$BIN

MAX_CONCURRENT_STREAMS=1
HEADER_TABLE_SIZE=4096
WINDOW_BITS=16
MAX_FRAME_SIZE=16384

while true; do
  case "$1" in
    --max-concurent-streams)    MAX_CONCURRENT_STREAMS=$2; shift; shift ;;
    --header-table-size)        HEADER_TABLE_SIZE=$2; shift; shift ;;
    --window-bits)              WINDOW_BITS=$2; shift; shift ;;
    --max-frame-size)           MAX_FRAME_SIZE=$2; shift; shift ;;
    --max-header-list-size)     MAX_HEADER_LIST_SIZE=$2; shift; shift ;;
    -o | --output )             OUTPUT=$2; shift; shift ;;
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

run_h2load() {
	CMD=h2load

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

    eval $CMD $*
}

tmp=/tmp/h2load-$PID.log
# Execute server and store data
start_time=$(date +%s.%N)
run_h2load $* >> $tmp

summary() {
    end_time=$(date +%s.%N)

    # Send summary to specified output
    if [ -n "$OUTPUT" ];then
        awk -v start_time=$start_time -v end_time=$end_time  -f $SCRIPTS/h2load.awk $tmp >> $OUTPUT
    else
        awk -v start_time=$start_time -v end_time=$end_time  -f $SCRIPTS/h2load.awk $tmp
    fi

    rm $tmp
}

trap summary SIGTERM EXIT
