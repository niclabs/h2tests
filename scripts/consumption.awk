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

FNR > 9 {
    time = $4 "." $5
	if (time >= start_time && time <= end_time) {
		power += $6
		voltage += $7
		current += $8

		power_sq += $6*$6
		voltage_sq += $7*$7
		current_sq += $8*$8

		rows += 1
	}
}

END {
    if (rows > 0) {
	    printf "%-10.6f %-10.6f ", power / rows,  sqrt(zero((power_sq / rows) - (power / rows) ^ 2))
	    printf "%-10.6f %-10.6f ", voltage / rows,  sqrt(zero((voltage_sq / rows) - (voltage / rows) ^ 2))
	    printf "%-10.6f %-10.6f ", power / rows,  sqrt(zero((current_sq / rows) - (current / rows) ^ 2))
    }
    else {
        printf "%-10s %-10s ", 0, 0
        printf "%-10s %-10s ", 0, 0
        printf "%-10s %-10s ", 0, 0
    }
}
