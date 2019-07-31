BEGIN {
    req_time_min = 1e24
    req_time_max = -1
    total = failed
}
# Round fractional parts smaller than 1e-14 to 0
function zero(x, ival, aval, fraction)
{
   ival = int(x)    # integer part, int() truncates

   # see if fractional part
   if (ival == x)   # no fraction
      return ival   # ensure no decimals

   if (x < 0) {
      aval = -x     # absolute value
      ival = int(aval)
      fraction = aval - ival
      if (fraction >= 1e-14)
         return int(x) + fraction   # -2.5 --> -3
      else
         return int(x)       # -2.3 --> -2
   } else {
      fraction = x - ival
      if (fraction >= 1e-14)
         return ival + fraction
      else
         return ival
   }
}

{
    if (rows == 0) {
        start_time = $1
    }
    end_time = $2 

    total += $3
    success += $3
    failed += (1 - $3)

    req_time_min = req_time_min - $4 < 0 ? req_time_min : $4
    req_time_max = req_time_max - $4 > 0 ? req_time_max : $4
        
    req_time += $4
    req_time_sq += $4*$4

    rows += 1
}

END {
    if (rows > 0) {
        printf "%20s %20s ", start_time, end_time
        printf "%-8s %-8s %-8s ", total, success, failed
        printf "%-12s %-12s %-12s %-12s ", (req_time_min * 1000) "ms", (req_time_max * 1000) "ms", (req_time / rows) * 1000 "ms", sqrt(zero((req_time_sq / rows) - (req_time / rows) ^ 2)) * 1000 "ms"

        # get hostname
        "hostname" | getline hostname
        gsub(/[ \n\t\r]+$/, "", hostname)
        printf "%-12s\n", hostname
    }
}
