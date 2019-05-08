BEGIN {
    # Print headers
    printf "%-6s", "total"
    printf "%-9s", "success"
    printf "%-7s", "failed"
    printf "%-13s", "req-time-min"
    printf "%-13s", "req-time-max"
    printf "%-13s", "req-time-avg"
    printf "%-13s", "req-time-std"
    printf "\n"
}

$0 ~ /^requests:/ {
    # Print request data
    printf "%-6s", $2 # total
    printf "%-9s", $8 # success
    printf "%-7s", $10 # failed
}

$0 ~ /^time for request:/ {
    printf "%-13s", $4 # req-time-min
    printf "%-13s", $5 # req-time-max
    printf "%-13s", $6 # req-time-avg
    printf "%-13s", $7 # req-time-std
    printf "\n"
}
