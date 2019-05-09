#!/bin/bash

SCRIPT=$0
OPTS=`getopt -o s:c:a:p:n:h --long h2-clients:,h2-requests:,name:port:address:client:,server:,help -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

usage() {
    echo "Usage $SCRIPT [options]"
    if [ -n "$1" ]; then
        echo -e "Error: $1"
    fi

    echo "Options:"
    echo "-a <ip>, --address=<ip> IP address of the server node"
    echo "-p <num>, --port=<num> PORT where http server will run"
    echo "-n <str>, --name=<num> experiment name to prefix output files"
    echo "-s <num>, --server=<num> IoT-Lab server node for running experiments"
    echo "-c <num>, --client=<num> IoT-Lab client node for running experiments"
    echo "-h, --help Print this message"
}


IPV6_ADDR=${IPV6_ADDR:-"2001:dead:beef::1"}
HTTP_PORT=${HTTP_PORT:-80}
NAME=$$

# Number of clients for h2load
H2LOAD_CLIENTS=96
H2LOAD_REQUESTS=131072

while true; do
  case "$1" in
    -a | --address)  IPV6_ADDR=$2; shift; shift ;;
    -p | --port)     HTTP_PORT=$2; shift; shift ;;
    -n | --name)     NAME=$2; shift; shift ;;
    -s | --server)   IOTLAB_SERVER=$2; shift; shift ;;
    -c | --client)   IOTLAB_CLIENT=$2; shift; shift ;;
    --h2-clients)    H2LOAD_CLIENTS=$2; shift; shift ;;
    --h2-requests)   H2LOAD_REQUESTS=$2; shift; shift ;;
    -h | --help )    usage; exit 0 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ -n "$IOTLAB_SERVER" ]; then
    [[ $IOTLAB_SERVER -gt 0 ]] || { usage "IoT-Lab server node number must be greater than 0"; exit 1; }

    # Parameters for make
    MAKE_PREFIX_SERVER="iotlab-node-$IOTLAB_SERVER-"
    MAKE_ENV="PREFIX_DISABLE=1"
fi

if [ -n "$IOTLAB_CLIENT" ]; then
    [[ $IOTLAB_CLIENT -gt 0 ]] || { usage "IoT-Lab client node number must be greater than 0"; exit 1; }

    # Parameters for make
    MAKE_PREFIX_CLIENT="iotlab-node-$IOTLAB_CLIENT-"
    MAKE_ENV="PREFIX_DISABLE=1"
fi

# Default directories
BIN=${BIN:-"./bin"}
WWW=${WWW:-"./build/www"}
RESULTS=${RESULTS:-"./results"}
SCRIPTS=${SCRIPTS:-"./scripts"}

# Result directories
EXPERIMENTS=$RESULTS/$NAME/experiments
AGGREGATE=$RESULTS/$NAME/aggregate

# Create directories
mkdir -p $WWW
mkdir -p $EXPERIMENTS
mkdir -p $AGGREGATE

# Default index.html size is 512 bytes
INDEX_HTML_SIZE=${INDEX_HTML_SIZE:-512}

# Fixed HTTP2 parameters
MAX_CONCURRENT_STREAMS=1

# Default HTTP2 parameters
HEADER_TABLE_SIZE_DEFAULT=4096
WINDOW_BITS_DEFAULT=16
MAX_FRAME_SIZE_DEFAULT=16384
MAX_HEADER_LIST_SIZE_DEFAULT=

# Variable HTTP2 parameters
HEADER_TABLE_SIZE_RANGE=$(seq 1 4096)
WINDOW_BITS_RANGE=$(seq 0 30)
MAX_FRAME_SIZE_RANGE=$(seq 14 24) # 2**n
MAX_HEADER_LIST_SIZE_RANGE=$(seq 1 4096)

setup() {
    # Create random index file to prevent caching
    head -c $INDEX_HTML_SIZE < /dev/urandom > $WWW/index.html
}

cleanup() {
    # Remove index file
    rm build/www/index.html
}

nghttpd() {
    ENV="$MAKE_ENV R_HTTP_PORT=$HTTP_PORT R_IPV6_ADDR=$IPV6_ADDR"
    ENV="$ENV R_MAX_CONCURRENT_STREAMS=$MAX_CONCURRENT_STREAMS R_HEADER_TABLE_SIZE=$1 R_WINDOW_BITS=$2 R_MAX_FRAME_SIZE=$3"

	if [ -n "$4" ]; then
        ENV="$ENV R_MAX_HEADER_LIST_SIZE=$4"
    fi

    exec env $ENV make ${MAKE_PREFIX_SERVER}nghttpd
}

h2load() {
    ENV="$MAKE_ENV R_HTTP_PORT=$HTTP_PORT R_IPV6_ADDR=$IPV6_ADDR"
    ENV="$ENV R_MAX_CONCURRENT_STREAMS=$MAX_CONCURRENT_STREAMS R_HEADER_TABLE_SIZE=$1 R_WINDOW_BITS=$2 R_MAX_FRAME_SIZE=$3"

	if [ -n "$4" ]; then
        ENV="$ENV R_MAX_HEADER_LIST_SIZE=$4"
    fi

    ENV="$ENV R_CLIENTS=$H2LOAD_CLIENTS R_REQUESTS=$H2LOAD_REQUESTS"

    exec env $ENV make ${MAKE_PREFIX_CLIENT}h2load
}

run_experiment() {
    echo "$(date)> starting experiment with header_table_size=$1 window_bits=$2 max_frame_size=$3 max_header_list_size=$4" >&2
    setup

    SUFFIX="$1-$2-$3-d"
    if [ -n "$4" ]; then
        SUFFIX="$1-$2-$3-$4"
    fi

    NGHTTPD_OUT=$EXPERIMENTS/nghttp-$SUFFIX.txt
    H2LOAD_OUT=$EXPERIMENTS/h2load-$SUFFIX.txt

    # create file descriptor for writing
    # warning: this fails in OS X
    exec 3<> <(cat)
    CAT_PID=$!

    # Run nghttpd
    echo "Running nghttpd" >&2
    exec 4< <(nghttpd $1 $2 $3 $4 <&3)
    NGHTTPD_PID=$!

    # Give time to the server to start
    sleep 2
    echo "nghttpd started ($NGHTTPD_PID)" >&2

    # Run h2load
    echo "Running h2load" >&2
    h2load $1 $2 $3 $4 > $H2LOAD_OUT &
    wait $!

    echo "h2load finished, terminating server and calculating results" >&2

    # Kill server and children
    echo 'q' >&3
    cat <&4 > $NGHTTPD_OUT

    # close file descriptors
    exec 3<&-
    exec 3>&-
    exec 4<&-
    kill -- $CAT_PID

    # get start time and end time from h2load
    start_time=$(awk '/^start-time:/{gsub(/[ \n\t\r]+$/, "", $2); printf $2}' $H2LOAD_OUT)
    end_time=$(awk '/^end-time:/{gsub(/[ \n\t\r]+$/, "", $2); printf $2}' $H2LOAD_OUT)

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

    echo "$(date) > finishing experiment with header_table_size=$1 window_bits=$2 max_frame_size=$3 max_header_list_size=$4" >&2
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
    MAX_HEADER_LIST_SIZE=$MAX_HEADER_LIST_SIZE_DEFAULT

    OUT=$AGGREGATE/header_table_size.txt
    if [[ -f $OUT ]] &&
        header_table_size_tmp=$(tail -n 1 $OUT | awk '{printf $3}') &&
        [[ -n "$header_table_size_tmp" ]]  && [[ $header_table_size_tmp =~ ^[0-9]+$ ]]; then
        header_table_size_start=$header_table_size_tmp
    else
        header_table_size_start=$(echo $HEADER_TABLE_SIZE_RANGE | cut -d " " -f 1)
        headers > $OUT
    fi

    for header_table_size in $HEADER_TABLE_SIZE_RANGE
    do
        [ $header_table_size -lt $header_table_size_start ] && continue
        run_experiment $header_table_size $WINDOW_BITS $MAX_FRAME_SIZE "$MAX_HEADER_LIST_SIZE" $OUT
    done
}

test_window_bits() {
    HEADER_TABLE_SIZE=$HEADER_TABLE_SIZE_DEFAULT
    MAX_FRAME_SIZE=$MAX_FRAME_SIZE_DEFAULT
    MAX_HEADER_LIST_SIZE=$MAX_HEADER_LIST_SIZE_DEFAULT

    OUT=$AGGREGATE/window_bits.txt
    if [ -f $OUT ] &&
        window_bits_start_tmp=$(tail -n 1 $OUT | awk '{printf $4}') &&
        [[ -n "$window_bits_start_tmp" ]] && [[ $window_bits_start_tmp =~ ^[0-9]+$ ]]; then
        window_bits_start=$window_bits_start_tmp
    else
        window_bits_start=$(echo $WINDOW_BITS_RANGE | cut -d " " -f 1)
        headers > $OUT
    fi

    for window_bits in $WINDOW_BITS_RANGE
    do
        [ $window_bits -lt $window_bits_start ] && continue
        run_experiment $HEADER_TABLE_SIZE $window_bits $MAX_FRAME_SIZE "$MAX_HEADER_LIST_SIZE" $OUT
    done
}

test_max_frame_size() {
    WINDOW_BITS=$WINDOW_BITS_DEFAULT
    HEADER_TABLE_SIZE=$HEADER_TABLE_SIZE_DEFAULT
    MAX_HEADER_LIST_SIZE=$MAX_HEADER_LIST_SIZE_DEFAULT

    OUT=$AGGREGATE/max_frame_size.txt
    if [ -f $OUT ] &&
        max_frame_size_start_tmp=$(tail -n 1 $OUT | awk '{printf $5}') &&
        [[ -n "$max_frame_size_start_tmp" ]] && [[ $max_frame_size_start_tmp =~ ^[0-9]+$ ]]; then
        max_frame_size_start=$max_frame_size_start_tmp
    else
        max_frame_size_start=$(echo $MAX_FRAME_SIZE_RANGE | cut -d " " -f 1)
        headers > $OUT
    fi

    for max_frame_size in $MAX_FRAME_SIZE_RANGE
    do
        [ $max_frame_size -lt $max_frame_size_start ] && continue
        if [ $max_frame_size -eq 24 ]; then
            max_frame_size=$[2**$max_frame_size - 1]
        else
            max_frame_size=$[2**$max_frame_size]
        fi

        run_experiment $HEADER_TABLE_SIZE $WINDOW_BITS $max_frame_size "$MAX_HEADER_LIST_SIZE" $OUT
    done
}

test_max_header_list_size() {
    WINDOW_BITS=$WINDOW_BITS_DEFAULT
    HEADER_TABLE_SIZE=$HEADER_TABLE_SIZE_DEFAULT
    MAX_FRAME_SIZE=$MAX_FRAME_SIZE_DEFAULT

    OUT=$AGGREGATE/max_header_list_size.txt
    if [ -f $OUT ] &&
        max_header_list_size_tmp=$(tail -n 1 $OUT | awk '{printf $6}') &&
        [[ -n "$max_header_list_size_tmp" ]] && [[ $max_header_list_size_tmp =~ ^[0-9]+$ ]]; then
        max_header_list_size_start=$max_header_list_size_tmp
        :
    else
        max_header_list_size_start=$(echo $MAX_HEADER_LIST_SIZE_RANGE | cut -d " " -f 1)
        headers > $OUT
    fi

    for max_header_list_size in $MAX_HEADER_LIST_SIZE_RANGE
    do
        [ $max_header_list_size -lt $max_header_list_size_start ] && continue
        run_experiment $HEADER_TABLE_SIZE $WINDOW_BITS $MAX_FRAME_SIZE $max_header_list_size $OUT
    done
}


# RUN experiments
test_header_table_size
test_window_bits
test_max_frame_size
test_max_header_list_size
