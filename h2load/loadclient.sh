#repetitions
for (( k = 1; k <= 20; k++ ));
do
	#number of clients
	for (( i = 1; i <= 32; i++ ));
	do
	    #requests or duration
        for (( j = 1; j <= 16384; j=j*2 ));
		do
			h2load https://piserver.com:8010/index.html --requests=$j --clients=$i >> ./h2load/h2load"$i"_"$j".log
			wait
    	done
	done
done



