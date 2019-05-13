BEGIN {
    row = sprintf("%-20s %-20s ", start_time, end_time)

    # get hostname
    "hostname" | getline hostname
    gsub(/[ \n\t\r]+$/, "", hostname)
}

$0 ~ /^requests:/ {
    # Print request data
    row = row sprintf("%-8s ", $2) # total
    row = row sprintf("%-8s ", $8) # success
    row = row sprintf("%-8s ", $10) # failed
}

$0 ~ /^time for request:/ {
    row = row sprintf("%-12s ", $4) # req-time-min
    row = row sprintf("%-12s ", $5) # req-time-max
    row = row sprintf("%-12s ", $6) # req-time-avg
    row = row sprintf("%-12s ", $7) # req-time-std
}

END {
    row = row sprintf("%-12s ", hostname)
    print row
}
