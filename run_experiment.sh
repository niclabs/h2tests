# !/bin/bash

SCRIPT=$0
OPTS=`getopt -o s:c:a:p:n:t:h --long h2-clients:,h2-requests:,name:port:address:client:,server:,timeout:,help -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options."; exit 1 ; fi

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

# Number of clients for http2
HTTP2_CLIENTS=96
HTTP2_REQUESTS=131072

# Default timeout
TIMEOUT=0

while true; do
  case "$1" in
    -a | --address)  IPV6_ADDR=$2; shift; shift ;;
    -p | --port)     HTTP_PORT=$2; shift; shift ;;
    -n | --name)     NAME=$2; shift; shift ;;
    -s | --server)   IOTLAB_SERVER=$2; shift; shift ;;
    -c | --client)   IOTLAB_CLIENTS=$2; shift; shift ;;
    -t | --timeout)  TIMEOUT=$2; shift; shift ;;
    --h2-clients)    HTTP2_CLIENTS=$2; shift; shift ;;
    --h2-requests)   HTTP2_REQUESTS=$2; shift; shift ;;
    -h | --help )    usage; exit 0 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

MAKE_ENV="PREFIX_DISABLE=1"
IPV6_PREFIX=$IPV6_ADDR/64
TTY=/dev/ttyA8_M3

# Default directories
BIN=${BIN:-"./bin"}
WWW=${WWW:-"./build/www"}
RESULTS=${RESULTS:-"./results"}
SCRIPTS=${SCRIPTS:-"./scripts"}

# Result directories
AGGREGATE=$RESULTS/$NAME
SERVER=$RESULTS/$NAME/server
CLIENTS=$RESULTS/$NAME/clients

# Create directories
mkdir -p $RESULTS
mkdir -p $WWW
mkdir -p $SERVER
mkdir -p $CLIENTS

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
WINDOW_BITS_RANGE=$(seq 1 30)
MAX_FRAME_SIZE_RANGE=$(seq 14 24) # 2**n
MAX_HEADER_LIST_SIZE_RANGE=$(seq 1 4096)

exec_in_a8() {
    node=$1; shift
    cmd="cd ~/A8/http2-parameters-for-iot && $(printf "%q " "$@")"
    echo "node-a8-$node: $cmd" >&2
    exec ssh -tt root@node-a8-$node $cmd
}

run_in_a8() {
    node=$1; shift
    cmd="cd ~/A8/http2-parameters-for-iot && $(printf "%q " "$@")"
    echo "node-a8-$node: $cmd" >&2
    ssh -tt root@node-a8-$node $cmd
}


setup_experiment() {
    # Create random index file to prevent caching
    head -c $INDEX_HTML_SIZE < /dev/urandom > $WWW/index.html
}

cleanup_experiment() {
    # Remove index file
    rm $WWW/index.html
}

launch_slip_bridge() {
	exec_in_a8 $1 $BIN/slip-bridge.native -s $TTY -B 500000
}

launch_slip_router() {
	exec_in_a8 $1 $BIN/slip-bridge.native -s $TTY -r $IPV6_PREFIX -B 500000
}

launch_server() {
    out=$5
    if [ -n "$IOTLAB_SERVER" ]; then
        exec_in_a8 $IOTLAB_SERVER ./scripts/nghttpd.sh -o $out \
            --max-concurrent-streams=$MAX_CONCURRENT_STREAMS \
            --header-table-size=$1 \
            --window-bits=$2 \
            --max-frame-size=$3 $(test -n "$4" && echo "--max-header-list-size=$4") \
            -d $WWW $HTTP_PORT $BIN/server.key $BIN/server.crt
    else
        ./scripts/nghttpd.sh -o $out \
            --max-concurrent-streams=$MAX_CONCURRENT_STREAMS \
            --header-table-size=$1 \
            --window-bits=$2 \
            --max-frame-size=$3 $(test -n "$4" && echo "--max-header-list-size=$4") \
            -d $WWW $HTTP_PORT $BIN/server.key $BIN/server.crt
    fi
}

launch_clients() {
    local out=$5
    local client_pids=()
    
    # write client headers
    echo "header_table_size: $1" > $out
    echo "window_bits: $2" >> $out
    echo "max_frame_size: $3" >> $out
    echo "max_header_list_size: $4" >> $out
    echo "" >> $client_out
    printf "%-20s %-20s " "start-time" "end-time" >> $out
    printf "%-8s %-8s %-8s %-12s %-12s %-12s %-12s " "total" "success" "failed" "req-time-min" "req-time-max" "req-time-avg" "req-time-std" >> $out
    printf "%-12s" "hostname" >> $out
    printf "\n" >> $out

    if [ -n "$IOTLAB_CLIENTS" ]; then
        # launch all clients
        for node in $(split , $IOTLAB_CLIENTS)
        do
            run_in_a8 $node ./scripts/run-http-client.sh -o $out \
                --max-concurrent-streams=$MAX_CONCURRENT_STREAMS \
                --header-table-size=$1 \
                --window-bits=$2 \
                --max-frame-size=$3 $(test -n "$4" && echo "--max-header-list-size=$4") \
                -n $HTTP2_REQUESTS \
                https://[$IPV6_ADDR]:$HTTP_PORT &
            client_pids+=($!)
        done
        echo "Clients launched (${client_pids[*]}), waiting maximum of $TIMEOUT(s)" >&2
        # wait for all clients to finish
        wait_for_pids $TIMEOUT ${client_pids[*]}
    else
        ./scripts/run-http-client.sh -o $out \
            --max-concurrent-streams=$MAX_CONCURRENT_STREAMS \
            --header-table-size=$1 \
            --window-bits=$2 \
            --max-frame-size=$3 $(test -n "$4" && echo "--max-header-list-size=$4") \
            -n $HTTP2_REQUESTS \
            https://[$IPV6_ADDR]:$HTTP_PORT
    fi
}

run_experiment() {
    echo "Starting experiment with header_table_size=$1 window_bits=$2 max_frame_size=$3 max_header_list_size=$4" >&2
    setup_experiment

    SUFFIX="$1-$2-$3-d"
    if [ -n "$4" ]; then
        SUFFIX="$1-$2-$3-$4"
    fi

    nghttpd_out=$SERVER/nghttpd-$SUFFIX.txt
    client_out=$CLIENTS/nghttp-$SUFFIX.txt

    # Run nghttpd
    echo "Starting server" >&2
    redirect_right launch_server $1 $2 $3 "$4" $nghttpd_out
    server_in=$?
    server_pid=$!

    # Give time to the server to start
    echo "Wait 2s for server to start" >&2
    sleep 2
    echo "Server started" >&2

    
    # start client
    echo "Launching clients" >&2
    launch_clients $1 $2 $3 "$4" $client_out
    echo "Clients finished, sending signal to server" >&2

    # kill server
    echo 'q' >&$server_in

    # wait for the process to finish
    echo -n "Waiting for server to finish ... " >&2
    local elapsed=0
    local expired=0
    while [ -e /proc/$server_pid ] && [ $expired -eq 0 ] #wait at most 5 seconds
    do
        echo 'q' >&$server_in # just in case
        sleep .6
        elapsed=$(echo - | awk "{print $elapsed + .6}")
        expired=$(echo "$elapsed 5" | awk '{print ($1 > $2)}')
    done

    # kill processes
    close_fd $server_in

    # write results
    echo "Writing results" >&2
    # get start time and end time from nghttpd
    start_time=$(awk '/^start-time:/{gsub(/[ \n\t\r]+$/, "", $2); printf $2}' $nghttpd_out)
    end_time=$(awk '/^end-time:/{gsub(/[ \n\t\r]+$/, "", $2); printf $2}' $nghttpd_out)

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
    awk -f $SCRIPTS/summarize-client-totals.awk $client_out >> $5

    # cpu-avg cpu-std mem-avg mem-std
    awk -f $SCRIPTS/nghttpd.awk -v start_time=$start_time -v end_time=$end_time $nghttpd_out >> $5

    # calculate consumption if running in iot-lab (untested)
    if [ -d $HOME/.iot-lab/$IOTLAB_ID/consumption ] && [ -n "$IOTLAB_SERVER" ]; then
       awk -f $SCRIPTS/consumption.awk -v start_time=$start_time -v end_time=$end_time $HOME/.iot-lab/$IOTLAB_ID/consumption/a8_$IOTLAB_SERVER.oml >> $5
    fi

    # print newline
    echo "" >> $5

    echo "Finishing experiment with header_table_size=$1 window_bits=$2 max_frame_size=$3 max_header_list_size=$4" >&2
    cleanup_experiment
}

headers() {
    # Print headers
    printf "%-20s %-20s " "start-time" "end-time"
    printf "%-17s %-11s %-14s %-20s " "header-table-size" "window-bits" "max-frame-size" "max-header-list-size"
    printf "%-8s %-8s %-8s " "total" "success" "failed"
    printf "%-10s %-10s %-10s " "req-min-ms" "req-max-ms" "req-avg-ms" # "req-time-std"
    printf "%-10s %-10s %-10s %-10s" "cpu-avg" "cpu-std" "mem-avg" "mem-std"
    if [ -d $HOME/.iot-lab/$IOTLAB_ID/consumption ] && [ -n "$IOTLAB_SERVER" ]; then
        printf "%-10s %-10s " "power-avg" "power-std"
        printf "%-10s %-10s " "volt-avg" "volt-std"
        printf "%-10s %-10s " "curr-avg" "curr-std"
    fi
    printf "\n"
}

test_header_table_size() {
    WINDOW_BITS=$WINDOW_BITS_DEFAULT
    MAX_FRAME_SIZE=$MAX_FRAME_SIZE_DEFAULT
    MAX_HEADER_LIST_SIZE=$MAX_HEADER_LIST_SIZE_DEFAULT

    OUT=$AGGREGATE/header_table_size.txt
    if [[ -f $OUT ]] &&
        header_table_size_tmp=$(tail -n 1 $OUT | awk '{printf $3}') &&
        [[ -n "$header_table_size_tmp" ]]  && [[ $header_table_size_tmp =~ ^[0-9]+$ ]]; then
        header_table_size_start=$[header_table_size_tmp + 1]
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
    if [[ -f $OUT ]] &&
        window_bits_start_tmp=$(tail -n 1 $OUT | awk '{printf $4}') &&
        [[ -n "$window_bits_start_tmp" ]] && [[ $window_bits_start_tmp =~ ^[0-9]+$ ]]; then
        window_bits_start=$[window_bits_start_tmp + 1]
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
    if [[ -f $OUT ]] &&
        max_frame_size_start_tmp=$(tail -n 1 $OUT | awk '{printf $5}') &&
        [[ -n "$max_frame_size_start_tmp" ]] && [[ $max_frame_size_start_tmp =~ ^[0-9]+$ ]]; then
        max_frame_size_start=$[max_frame_size_start_tmp + 1]
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
    if [[ -f $OUT ]] &&
        max_header_list_size_tmp=$(tail -n 1 $OUT | awk '{printf $6}') &&
        [[ -n "$max_header_list_size_tmp" ]] && [[ $max_header_list_size_tmp =~ ^[0-9]+$ ]]; then
        max_header_list_size_start=$[max_header_list_size_tmp + 1]
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

open_fd() {
    [ -n "${fds[*]}"] || fds=()

    for i in {5..100}; do # 1 .. 4 are reserved
        # ugly: if removing the element does nothing then it is not used
        if [ ${fds} = ${fds[@]#$i} ]; then
            fds+=($i)
            return $i
        fi
    done
    echo "Too many file descriptors"; exit 1
}

close_fd() {
    # if there is a related process, kill the process if running
    if [ -n "${pids[$1]}" ]; then
        kill -- ${pids[$1]} > /dev/null 2>&1 # the process may not exist so we ignore output
        pids=${pids[@]#$1} #remove from array
    fi
    eval "exec $1<&-"
    eval "exec $1>&-"
    fds=${fds[@]#$1} #remove from array
}

close_all_fds() {
    for i in $fds; do
        close_fd $i
    done
}

register_fd() {
    if [ -n "$2" ]; then
        pids[$1]=$2
    fi
    fds+=($1)
}

wait_for_pids() {
    local timeout=$1; shift

    local elapsed=0
    local sleep=0.6
    local expired=0
    local running=1
    while [ $running -eq 1 ] && [ $expired -eq 0 ]
    do
        running=0
        for pid in "$@"
        do
            if [ -e /proc/$pid ]; then
                running=1
            fi
        done

        # Sleep and update elapsed time
        sleep $sleep
        elapsed=$(echo "$elapsed $sleep" | awk '{print ($1 + $2)}')
        if [ $timeout -gt 0 ]; then
            expired=$(echo "$elapsed $timeout" | awk '{print ($1 > $2)}')
        fi
    done

    # Time has expired
    if [ $expired -eq 1 ]; then
        for pid in "$@"
        do
            if [ -e /proc/$pid ]; then
                echo "Timeout reached for pid $pid, terminating the process"
                kill -- $pid > /dev/null 2>&1
            fi
        done

        # return error
        return 1
    fi

    return 0
}

redirect_left() {
    exec {fd}< <(eval $(printf "%q " "$@")) #explanation https://stackoverflow.com/a/3179059
    register_fd $fd $resources!
    return $fd
}

redirect_right() {
    exec {fd}> >(eval $(printf "%q " "$@")) #explanation https://stackoverflow.com/a/3179059
    register_fd $fd $!
    return $fd
}

function join() {
    local IFS="$1"; shift; echo "$*";
}

function split() {
    local IFS=$1; shift
    read -r -a array <<< "$*"
    echo ${array[@]}
}

submit_experiment_if_needed() {
    # check if we are running in iot-lab
    [[ -z "$IOTLAB_SERVER" ]] && [[ -z "$IOTLAB_CLIENTS" ]] && return

    # check if experiment is running
    local iotlab_id_tmp=$(make iotlab-id)

    if [[ $iotlab_id_tmp =~ ^[0-9]+$ ]]; then
        IOTLAB_ID=$iotlab_id_tmp
    else
        local resources=$(join + $IOTLAB_SERVER $(split , $IOTLAB_CLIENTS))
        # not found, launch experiment
        eval $MAKE_ENV IOTLAB_RESOURCES=$resources make iotlab-submit

        iotlab_id_tmp=$(make iotlab-id)
        [[ $iotlab_id_tmp =~ ^[0-9]+$ ]] || (echo "Could not launch experiment" && exit 1)
        IOTLAB_ID=$iotlab_id_tmp

        echo "Waiting 60 seconds until nodes get started"
        sleep 60
    fi
}

prepare_server() {
    # if not running server or clients in iot-lab no need to flash radio
    [ -n "$IOTLAB_SERVER" ] || return
    [ -n "$IOTLAB_CLIENTS" ] || return

    # Flash server radio and launch slip-router
    echo "Flashing radio on node $IOTLAB_SERVER" >&2
    (eval $MAKE_ENV make iotlab-node-$IOTLAB_SERVER-flash-slip-radio) || (echo "Failed to flash radio for node $IOTLAB_SERVER" >&2 && exit 1)

    echo "Launching slip-router on node $IOTLAB_SERVER" >&2
    redirect_right launch_slip_router $IOTLAB_SERVER

    echo "Wait 5s for slip-router to launch on node $IOTLAB_SERVER" >&2
    sleep 5
}


prepare_clients() {
    # if not running client in iot-lab do not flash radio
    [ -n "$IOTLAB_CLIENTS" ] || return
    [ -n "$IOTLAB_SERVER" ] || return
    [ $HTTP2_CLIENTS -gt 1 ] && (echo "Number of clients running per node in iot-lab cannot be greater than 1" ; exit 1)

    for node in $(split , $IOTLAB_CLIENTS)
    do
        # Flash server radio and launch slip-router
        echo "Flashing radio on node $node" >&2
        (eval $MAKE_ENV make iotlab-node-$node-flash-slip-radio) || (echo "Failed to flash radio for node $node" >&2 && exit 1)

        echo "Launching slip-bridge on node $node" >&2
        redirect_right launch_slip_bridge $node

        echo "Wait 5s for slip-bridge to launch on node $node" >&2
        sleep 5
    done
}

finish() {
    status=$?

    # Perform cleanup tasks
    close_all_fds

    exit $status
}

trap finish SIGINT SIGTERM EXIT

# prepend date in all output
#exec > >(sed "s/^/$(date -u +'%F %T') /")
#exec 2> >(sed "s/^/$(date -u +'%F %T') /" >&2)

# Submit experiment if not running
submit_experiment_if_needed

# prepare server before launching
prepare_server

prepare_clients

# RUN experiments
#run_experiment 67 16 16384 4096 test.txt

test_header_table_size
test_window_bits
test_max_frame_size
test_max_header_list_size
