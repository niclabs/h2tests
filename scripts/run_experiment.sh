#!/bin/bash

SCRIPT=$0
OPTS=`getopt -o s:c:h --long iotlab-client:,iotlab-server:,help -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

usage() {
    echo "Usage $SCRIPT [options]"
    if [ -n "$1" ]; then
        echo -e "Error: $1"
    fi

    echo "Options:"
    echo "-s <n>  --iotlab-server=<n> IoT-Lab server node for running experiments"
    echo "-c <n>, --iotlab-client=<n> IoT-Lab client node for running experiments"
    echo "-h, --help Print this message"
}

while true; do
  case "$1" in
    -s  |--iotlab-server)   IOTLAB_SERVER=$2; shift; shift ;;
    -c  |--iotlab-client)   IOTLAB_CLIENT=$2; shift; shift ;;
    -h | --help )           usage; exit 0 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ -n "$IOTLAB_SERVER" ] && [ -n "$IOTLAB_CLIENT" ]; then
    [[ $IOTLAB_SERVER -gt 0 ]] && [[ $IOTLAB_CLIENT -gt 0 ]] || { usage "Both, server and client must be greater than 0"; exit 1; }

    IOTLAB=1

    # Parameters for make
    MAKE_PREFIX_SERVER="iotlab-node-$IOTLAB_SERVER-"
    MAKE_PREFIX_CLIENT="iotlab-node-$IOTLAB_CLIENT-"
    MAKE_ENV="PREFIX_DISABLE=1"
fi

# Default directories
BIN=${BIN:-"./bin"}
WWW=${WWW:-"./build/www"}
RESULTS=${RESULTS:-"./results"}
SCRIPTS=${SCRIPTS:-"./scripts"}

# Default index.html size is 512 bytes
INDEX_HTML_SIZE=${INDEX_HTML_SIZE:-512}

HTTP_PORT=${HTTP_PORT:-8888}
IPV6_ADDR=${IPV6_ADDR:-"::1"}

# Number of clients for h2load
H2LOAD_CLIENTS=96
H2LOAD_REQUESTS=131072
#H2LOAD_CLIENTS=1
#H2LOAD_REQUESTS=1



# Fixed HTTP2 parameters
MAX_CONCURRENT_STREAMS=1

# Default HTTP2 parameters
HEADER_TABLE_SIZE_DEFAULT=4096
WINDOW_BITS_DEFAULT=16
MAX_FRAME_SIZE_DEFAULT=16384
MAX_HEADER_TABLE_LIST_SIZE_DEFAULT=

# Variable HTTP2 parameters
HEADER_TABLE_SIZE_RANGE=$(seq 1 4096)
WINDOW_BITS_RANGE=$(seq 0 30)
MAX_FRAME_SIZE_RANGE=$(seq 14 24) # 2**n
MAX_HEADER_TABLE_LIST_SIZE_RANGE=$(seq 1 4096)

setup() {
    # Create random index file to prevent caching
    head -c $INDEX_HTML_SIZE < /dev/urandom > $WWW/index.html
}

cleanup() {
    # Remove index file
    rm build/www/index.html
}

nghttpd() {
    ENV="HTTP_PORT=$HTTP_PORT IPV6_ADDR=$IPV6_ADDR"
    ENV="$ENV MAX_CONCURRENT_STREAMS=$MAX_CONCURRENT_STREAMS HEADER_TABLE_SIZE=$1 WINDOW_BITS=$2 MAX_FRAME_SIZE=$3"

	if [ -n "$4" ]; then
        ENV="$ENV MAX_HEADER_LIST_SIZE=$4"
    fi

    echo "$ENV make ${MAKE_PREFIX_SERVER}nghttpd" >&2
    exec env $ENV make ${MAKE_PREFIX_SERVER}nghttpd${MAKE_SUFFIX}
}

h2load() {
    ENV="HTTP_PORT=$HTTP_PORT IPV6_ADDR=$IPV6_ADDR"
    ENV="$ENV MAX_CONCURRENT_STREAMS=$MAX_CONCURRENT_STREAMS HEADER_TABLE_SIZE=$1 WINDOW_BITS=$2 MAX_FRAME_SIZE=$3"

	if [ -n "$4" ]; then
        ENV="$ENV MAX_HEADER_LIST_SIZE=$4"
    fi

    ENV="$ENV CLIENTS=$H2LOAD_CLIENTS REQUESTS=$H2LOAD_REQUESTS"

    echo "$ENV make ${MAKE_PREFIX_CLIENT}h2load" >&2
    exec env $ENV make ${MAKE_PREFIX_CLIENT}h2load${MAKE_SUFFIX}
}

run_experiment() {
    echo "starting experiment with paramenters ($1,$2,$3,$4)" >&2
    setup

    SUFFIX="$1-$2-$3-d"
    if [ -n "$4" ]; then
        SUFFIX="$1-$2-$3-$4"
    fi

    NGHTTPD_OUT=$RESULTS/exp/nghttp-$SUFFIX.txt
    H2LOAD_OUT=$RESULTS/exp/h2load-$SUFFIX.txt

    # Run nghttpd
    nghttpd $1 $2 $3 $4 > $NGHTTPD_OUT &
    NGHTTPD_PID=$!

    # Give time to the server to run
    sleep 2

    # Run h2load
    echo "Running h2load" >&2
    h2load $1 $2 $3 $4 > $H2LOAD_OUT &
    wait $!

    echo "h2load finished, terminating server and calculating results" >&2

    # Kill server
    kill $NGHTTPD_PID

    # get start time and end time from h2load
    start_time=$(awk '/^start-time:/{print $2}' $H2LOAD_OUT)
    end_time=$(awk '/^end-time:/{print $2}' $H2LOAD_OUT)

    # write experiment data
    # start-time end-time
    printf "%-20s %-20s " $start_time $end_time >> $5

    # header-table-size window-bits max-frame-size max-header-list-size
    printf "%-17s %-11s %-14s " $1 $2 $3 >> $5
    if [ -n "$4" ]; then
       printf "%-20s " $4 >> $5
    else
       printf "%-20s " "d" >> $5
    fi

    # total success failed req-time-min req-time-max req-time-avg req-time-std
    awk 'NR > 9 {printf "%-8s %-8s %-8s %-12s %-12s %-12s %-12s ", $1, $2, $3, $4, $5, $6, $7}' $H2LOAD_OUT >> $5

    # cpu-avg cpu-std mem-avg mem-std
    awk -f $SCRIPTS/nghttpd.awk -v start_time=$start_time -v end_time=$end_time $NGHTTPD_OUT >> $5

    # TODO: get consumption data if running on iotlab-node

    echo "finishing experiment with paramenters ($1,$2,$3,$4)" >&2
    cleanup
}

headers() {
    # Print headers
    printf "%-20s %-20s " "start-time" "end-time"
    printf "%-17s %-11s %-14s %-20s " "header-table-size" "window-bits" "max-frame-size" "max-header-list-size"
    printf "%-8s %-8s %-8s %-12s %-12s %-12s %-12s " "total" "success" "failed" "req-time-min" "req-time-max" "req-time-avg" "req-time-std"
    printf "%-10s %-10s %-10s %-10s\n" "cpu-avg" "cpu-std" "mem-avg" "mem-std"
}

test_header_table_size() {
    WINDOW_BITS=$WINDOW_BITS_DEFAULT
    MAX_FRAME_SIZE=$MAX_FRAME_SIZE_DEFAULT
    MAX_HEADER_TABLE_LIST_SIZE=$MAX_HEADER_TABLE_LIST_SIZE_DEFAULT

    OUT=$RESULTS/aggregate/header_table_size.txt

    headers > $OUT
    for header_table_size in $HEADER_TABLE_SIZE_RANGE
    do
        run_experiment $header_table_size $WINDOW_BITS $MAX_FRAME_SIZE "$MAX_HEADER_TABLE_LIST_SIZE" $OUT
    done
}

test_window_bits() {
    HEADER_TABLE_SIZE=$HEADER_TABLE_SIZE_DEFAULT
    MAX_FRAME_SIZE=$MAX_FRAME_SIZE_DEFAULT
    MAX_HEADER_TABLE_LIST_SIZE=$MAX_HEADER_TABLE_LIST_SIZE_DEFAULT

    OUT=$RESULTS/aggregate/window_bits.txt

    headers > $OUT
    for window_bits in $WINDOW_BITS_RANGE
    do
        run_experiment $HEADER_TABLE_SIZE $window_bits $MAX_FRAME_SIZE "$MAX_HEADER_TABLE_LIST_SIZE" $OUT
    done
}

test_max_frame_size() {
    WINDOW_BITS=$WINDOW_BITS_DEFAULT
    HEADER_TABLE_SIZE=$HEADER_TABLE_SIZE_DEFAULT
    MAX_HEADER_TABLE_LIST_SIZE=$MAX_HEADER_TABLE_LIST_SIZE_DEFAULT

    OUT=$RESULTS/aggregate/max_frame_size.txt

    headers > $OUT
    for max_frame_size in $MAX_FRAME_SIZE_RANGE
    do
        if [ $max_frame_size -eq 24 ]; then
            max_frame_size=$[2**$max_frame_size - 1]
        else
            max_frame_size=$[2**$max_frame_size]
        fi

        run_experiment $HEADER_TABLE_SIZE $WINDOW_BITS $max_frame_size "$MAX_HEADER_TABLE_LIST_SIZE" $OUT
    done
}

test_max_header_list_size() {
    WINDOW_BITS=$WINDOW_BITS_DEFAULT
    HEADER_TABLE_SIZE=$HEADER_TABLE_SIZE_DEFAULT
    MAX_FRAME_SIZE=$MAX_FRAME_SIZE_DEFAULT

    OUT=$RESULTS/aggregate/max_header_table_list_size.txt

    headers > $OUT
    for max_header_list_size in $MAX_HEADER_LIST_SIZE_RANGE
    do
        run_experiment $HEADER_TABLE_SIZE $WINDOW_BITS $MAX_FRAME_SIZE $max_header_table_list_size $OUT
    done
}

# Create directories
mkdir -p $RESULTS/exp
mkdir -p $RESULTS/aggregate
mkdir -p $WWW

# RUN experiments
test_header_table_size
test_window_bits
test_max_frame_size
test_max_header_list_size
