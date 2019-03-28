for (( k = 1; k <=4; k++ ));
do
	for (( i = 1; i <= 1; i=i*2 ));
	do
		#put random stuff in index.html
        pwgen -s 20 23 > /home/pi/Desktop/nghttp2/src/index.html &
        wait $!
        echo "iteration $k" >> max_header_4096.log
        #server
    	sudo /home/pi/Desktop/nghttp2/src/nghttpd 8010 /etc/ssl/private/piserver.com.key /etc/ssl/certs/piserver.com.crt &
        export NGHTTPD_PID=$!
    	#give some time to the server to be ready
        sleep 3s
        #top
    	top -b -d 0,01 | grep lt-nghttpd | awk '{print $8 "\t" $9 "\t" $10}' >> max_header_4096.log &
        export TOP_PID=$!
    	sleep 50s
        #kill top
        kill $TOP_PID
    	#kill server
    	sudo kill $NGHTTPD_PID
        #just to be extra sure
     	sudo killall -9 lt-nghttpd
        sudo killall -9 nghttpd
        sudo kill -TERM -$NGHTTPD_PID
        #ps axf | grep nghttpd | grep -v grep | awk '{print "sudo killall -9 " $1}' | sh
    	sudo fuser -k 8010/tcp
        sudo fuser -k 8010/udp
    	#ps axf | grep top | grep -v grep | awk '{print "sudo killall -9 " $1}' | sh
        echo "finished size $i, repetition $k"
	done
done
