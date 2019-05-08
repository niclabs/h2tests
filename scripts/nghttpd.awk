BEGIN {}

$0 ~/^Makefile:/ {}

FNR > 8 {
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
	    printf "%-7s %-7s %-7s %-7s\n", cpu / rows,  sqrt(cpu_sq / rows - (cpu / rows) ** 2), mem / rows, sqrt(mem_sq / rows - (mem / rows) ** 2)
    }
    else {
        printf "%-7s %-7s %-7s %-7s\n", 0, 0, 0, 0
    }
}
