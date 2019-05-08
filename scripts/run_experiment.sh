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

# Parameters for make
MAKE_PREFIX_SERVER=${MAKE_PREFIX_SERVER:-""} # iotlab-node-1
MAKE_PREFIX_CLIENT=${MAKE_PREFIX:_CLIENT-""} # iotlab-node-2
MAKE_SUFFIX=${MAKE_SUFFIX:-""} # -nop


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

    exec env $ENV make ${MAKE_PREFIX_SERVER}nghttpd${MAKE_SUFFIX}
}

h2load() {
    ENV="HTTP_PORT=$HTTP_PORT IPV6_ADDR=$IPV6_ADDR"
    ENV="$ENV MAX_CONCURRENT_STREAMS=$MAX_CONCURRENT_STREAMS HEADER_TABLE_SIZE=$1 WINDOW_BITS=$2 MAX_FRAME_SIZE=$3"

	if [ -n "$4" ]; then
        ENV="$ENV MAX_HEADER_LIST_SIZE=$4"
    fi

    ENV="$ENV CLIENTS=$H2LOAD_CLIENTS REQUESTS=$H2LOAD_REQUESTS"

    exec env $ENV make ${MAKE_PREFIX_CLIENT}h2load${MAKE_SUFFIX}
}

run_experiment() {
    setup

    SUFFIX="$1-$2-$3-default"
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
    h2load $1 $2 $3 $4 > $H2LOAD_OUT &
    wait $!

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
       printf "%-20s " "-" >> $5
    fi

    # total success failed req-time-min req-time-max req-time-avg req-time-std
    awk 'NR > 9 {printf "%-5s %-8s %-6s %-12s %-12s %-12s %-12s ", $1, $2, $3, $4, $5, $6, $7}' $H2LOAD_OUT >> $5

    # cpu-avg cpu-std mem-avg mem-std
    awk -f $SCRIPTS/nghttpd.awk -v start_time=$start_time -v end_time=$end_time $NGHTTPD_OUT >> $5

    # TODO: get consumption data if running on iotlab-node

    cleanup
}

headers() {
    # Print headers
    printf "%-20s %-20s " "start-time" "end-time"
    printf "%-17s %-11s %-14s %-20s " "header-table-size" "window-bits" "max-frame-size" "max-header-list-size"
    printf "%-5s %-8s %-6s %-12s %-12s %-12s %-12s " "total" "success" "failed" "req-time-min" "req-time-max" "req-time-avg" "req-time-std"
    printf "%-7s %-7s %-7s %-7s\n" "cpu-avg" "cpu-std" "mem-avg" "mem-std"
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
