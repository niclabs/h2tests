BEGIN { 
    printf "total"
    printf "\t"
    printf "success"
    printf "\t"
    printf "failed"
    printf "\t"
    printf "min-time"
    printf "\t"
    printf "max-time"
    printf "\t"
    printf "mean-time"
    printf "\t"
    printf "stdev-time"
    printf "\n"
}

$0 ~ /^requests:/ { results = $2 "\t" $8 "\t" $10 }
$0 ~ /^time for request:/ { results = results "\t" $4 "\t\t" $5 "\t" $6  "\t" $7 }

END { print results }
