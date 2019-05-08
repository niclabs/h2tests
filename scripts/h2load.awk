BEGIN { 
    printf "total"
    printf "\t"
    printf "success"
    printf "\t"
    printf "failed"
    printf "\t"
    printf "req-time-min"
    printf "\t"
    printf "req-time-max"
    printf "\t"
    printf "req-time-avg"
    printf "\t"
    printf "req-time-stdev"
    printf "\n"
}

$0 ~ /^requests:/ { results = $2 "\t" $8 "\t" $10 }
$0 ~ /^time for request:/ { results = results "\t" $4 "\t" $5 "\t" $6  "\t" $7 }

END { print results }
