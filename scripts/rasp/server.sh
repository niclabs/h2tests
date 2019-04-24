for (( i = 19; i <= 40; i++ ));
do
    top -b -d 0,01 | grep nghttpd | awk '{print $9 "\t" $10}' >> streams_$i.log &
	sleep 1
	sudo nghttpd 8010 /etc/ssl/private/piserver.com.key /etc/ssl/certs/piserver.com.crt --max-concurrent-streams=$i &
	sleep 60
	ps axf | grep nghttpd | grep -v grep | awk '{print "sudo kill -9 " $1}' | sh
    sleep 1s
    ps axf | grep top | grep -v grep | awk '{print "sudo kill -9 " $1}' | sh
    echo "finished"
    sleep 3s	
done
