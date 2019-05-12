BEGIN {}

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

FNR > 6 {
    total += $3
    success += $4
    failed += $5

    rows += 1
}

END {
    printf "%-8s %-8s %-8s ", total, success, failed
}
