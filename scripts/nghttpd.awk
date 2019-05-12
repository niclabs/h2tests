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

$0 ~/^Makefile:/ {}

FNR > 9 {
	if ($1 >= start_time && $1 <= end_time) {
		cpu += $2
		mem += $3

		cpu_sq += $2*$2
		mem_sq += $3*$3

		rows += 1
	}
}

END {
    # printf "%-8s%-8s%-8s%-8s", "cpu-avg", "cpu-std", "mem-avg", "mem-std"
    if (rows > 0) {
	    printf "%-10.6f %-10.6f %-10.6f %-10.6f", cpu / rows,  sqrt(zero((cpu_sq / rows) - (cpu / rows) ^ 2)), mem / rows, sqrt(zero((mem_sq / rows) - (mem / rows) ^ 2))
    }
    else {
        printf "%-10s %-10s %-10s %-10s", 0, 0, 0, 0
    }
}
