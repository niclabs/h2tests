BEGIN {
    # Print headers
    printf "%-8s", "total"
    printf "%-8s", "success"
    printf "%-8s", "failed"
    printf "%-13s", "req-time-min"
    printf "%-13s", "req-time-max"
    printf "%-13s", "req-time-avg"
    printf "%-13s", "req-time-std"
    printf "\n"
}

$0 ~ /^requests:/ {
    # Print request data
    printf "%-8s", $2 # total
    printf "%-8s", $8 # success
    printf "%-8s", $10 # failed
}

$0 ~ /^time for request:/ {
    printf "%-13s", $4 # req-time-min
    printf "%-13s", $5 # req-time-max
    printf "%-13s", $6 # req-time-avg
    printf "%-13s", $7 # req-time-std
    printf "\n"
}
