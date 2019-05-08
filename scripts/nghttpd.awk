BEGIN {}

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
	print cpu / rows "\t" sqrt(cpu_sq / rows - (cpu / rows) ** 2) "\t"  mem / rows "\t" sqrt(mem_sq / rows - (mem / rows) ** 2)
}
