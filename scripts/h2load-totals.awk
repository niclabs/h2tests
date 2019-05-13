BEGIN {
    req_min = 1e24
    req_max = -1
}
# Round fractional parts smaller than 1e-14 to 0
function zero(x,   ival, aval, fraction)
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

function str_to_millis(x) {
    if (index(x, "ms") > 0) return substr(x, 1, index(x,"ms") - 1)
    if (index(x, "us") > 0) return substr(x, 1, index(x,"us") - 1) / 1000.0
    if (index(x, "s") > 0) return substr(x, 1, index(x,"s") - 1) * 1000.0
}

FNR > 6 {
    total += $3
    success += $4
    failed += $5

    min = str_to_millis($6)
    max = str_to_millis($7)
    req_min = req_min < min ? req_min : min
    req_max = req_max > max ? req_max : max
    req_avg_total += str_to_millis($8) * $3

    rows += 1
}

END {
    printf "%-8s %-8s %-8s ", total, success, failed
    printf "%-8s %-8s %-8s ", req_min "ms", req_max "ms", req_avg_total / total "ms"
}
