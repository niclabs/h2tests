function str_to_secs(x) {
    gsub(/^[ \t\+]+/, "", x) # trim leading space and '+'
    if (index(x, "ms") > 0) return substr(x, 1, index(x,"ms") - 1) / 1000.0
    if (index(x, "us") > 0) return substr(x, 1, index(x,"us") - 1) / 1000000.0
    if (index(x, "ns") > 0) return substr(x, 1, index(x,"us") - 1) / 1000000000.0
    if (index(x, "s") > 0) return substr(x, 1, index(x,"s") - 1) * 1.0
}

BEGIN {
    read_header_line = 0
    count = 0
}

$0 ~ /^id  responseEnd requestStart  process code size request path$/ {
    read_header_line = 1
}

# Lines after the header line
$0 !~ /^id  responseEnd requestStart  process code size request path$/ {
    if (read_header_line) {
        count += 1
        request_start = str_to_secs($3)
        request_time = str_to_secs($4)
        end_time = start_time + request_start + request_time
        ok=0
        if ($5 == 200) {
            ok=1
        }

        printf "%-10.9f %-10.9f ", start_time, end_time
        printf "%2s %-4.8f", ok, request_time
    }
}

END {
    if (count == 0) {
        "date +%s.%N" | getline end_time
        gsub(/[ \n\t\r]+$/, "", end_time)
        printf "%-10.9f %-10.9f ", start_time, end_time
        printf "%-2s %-4.8f", 0, (end_time - start_time)
    }
    print ""
}
