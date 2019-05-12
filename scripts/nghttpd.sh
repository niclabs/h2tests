#!/bin/bash

SCRIPT=$0
PID=$$
OPTS=`getopt -o vhd:o: --long output:,max-concurrent-streams:,header-table-size:,window-bits:,max-frame-size:,max-header-list-size:,help -n $SCRIPT -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# Default directories
BIN=${BIN:-"./bin"}

# Update path with local bin dir
PATH=$PATH:$BIN

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

run_nghttpd() {
	CMD="nghttpd"

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
    cat <&4
}

run_top() {
    exec top -b -d 0.01 > >(grep  "nghttpd$" | awk '$8 ~ /^R$/ {printf "%-2s %-6s %-6s\n", system("echo -n `date +%s.%N`"), $9, $10}')
}

cleanup() {
    status=$?

    # kill running processes
    kill -- $TOP_PID 2>/dev/null
    kill -- $NGHTTPD_PID

    # Send summary to specified output
    if [ -n "$OUTPUT" ];then
        summary > $OUTPUT
    else
        summary
    fi

    # close file descriptors
    exec 3<&-
    exec 4<&-

    # exit with the last status given
    exit $status
}

# Open file descriptor 3 from stdin
exec 3<&0

# Catch term and interrupt signal
trap cleanup SIGTERM EXIT

# Execute server and store data
START_TIME=$(date +%s.%N)

# Start monitoring process
exec 4< <(run_top)
TOP_PID=$!

# Run nghttpd
run_nghttpd $* 1>&2 &
NGHTTPD_PID=$!

# Wait for 'q' character
while
    read -n 1 -u 3 key || break
    [ "$key" != "q" ]
do
    :
done
