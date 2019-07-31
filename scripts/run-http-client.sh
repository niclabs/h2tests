#!/bin/bash

SCRIPT=$0
PID=$$
OPTS=`getopt -o hvn:o: --long output:,num-requests:,max-concurrent-streams:,header-table-size:,window-bits:,max-frame-size:,max-header-list-size:,help -n $SCRIPT -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# Default directories
BIN=${BIN:-"./bin"}
SCRIPTS=${SCRIPTS:-"./scripts"}

# Update path with local bin dir
PATH=$PATH:$BIN

# Number of iterations
NUM_REQUESTS=1

MAX_CONCURRENT_STREAMS=1
HEADER_TABLE_SIZE=4096
WINDOW_BITS=16
MAX_FRAME_SIZE=16384

while true; do
  case "$1" in
    --max-concurrent-streams)    MAX_CONCURRENT_STREAMS=$2; shift; shift ;;
    --header-table-size)        HEADER_TABLE_SIZE=$2; shift; shift ;;
    --window-bits)              WINDOW_BITS=$2; shift; shift ;;
    --max-frame-size)           MAX_FRAME_SIZE=$2; shift; shift ;;
    --max-header-list-size)     MAX_HEADER_LIST_SIZE=$2; shift; shift ;;
    -o | --output )             OUTPUT=$2; shift; shift ;;
    -n | --num-requests )       NUM_REQUESTS=$2; shift; shift ;;
    -h | --help )               HELP=true; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

usage() {
    echo "Usage $SCRIPT [options] <uri>"
    echo "Options:"
    echo "--max-concurrent-streams=<n>      configure cleint max concurrent streams setting (1 by default)"
    echo "--header-table-size=<size>        configure client header table size setting"
    echo "--window-bits=<n>                 configure client window size setting with window size = 2**n -1"
    echo "--max-frame-size=<size>           configure client max frame size setting"
    echo "--max-header-list-size=<size>     configure client max header list size setting"
    echo "-n <n> | --num-requests=<n>       perform request <n> times"
    echo "-v                                enable verbose output"
}

get_nghttp_cmd() {
	local CMD=nghttp

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

    echo $CMD -s --no-dep $*
}

run_nghttp() {
    local start_time=$(date +%s.%N)
    # run command and parse results
    eval $* 2>/dev/null | awk -v start_time=$start_time -f $SCRIPTS/parse-nghttp-stats.awk # run the command
}

tmp=/tmp/nghttp-$PID.log


summary() {
    local failed=$((NUM_REQUESTS - performed))

    # echo "start-time           end-time             total    success  failed   req-time-min req-time-max req-time-avg req-time-std hostname"
    if [ -n "$OUTPUT" ];then
        awk -v failed=$failed -f $SCRIPTS/summarize-client-results.awk $tmp >> $OUTPUT
    else
        awk -v failed=$failed -f $SCRIPTS/summarize-client-results.awk $tmp
    fi
}

trap summary SIGTERM EXIT

# Run the command
nghttpd_cmd=$(get_nghttp_cmd $*)
performed=0
while [ $performed -lt $NUM_REQUESTS ]
do
    run_nghttp $nghttpd_cmd >> $tmp
    performed=$((performed + 1))
done
