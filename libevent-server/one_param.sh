#!/bin/bash

echo -n "Parameter name $n: "
# eg.: NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS
read PARAMETER

echo -n "Values for the parameter ${PARAMETER}: "
#eg.: 1 2 4 8 16 32
read VALUES

# In the server file, search for this line and remove it
sed -i 's|{NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS, 100}};|};|' /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c

# Remove old settings
sed -e '/{NGHTTP2\_SETTINGS\_/d' -i /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c

# Create a string with the new settings (include line breaks)
start='{'
middle=', '
end='} '
bl='\n'

# Concatenate parameters
for value in ${VALUES[@]}
do
	# Add value to setting
	settings=${start}${PARAMETER}${middle}$value$end
	echo $settings
	# Add settings
    sed -i 's|nghttp2_settings_entry\ iv\[.]\ =\ {|  nghttp2_settings_entry iv[1] = {\n'"$settings"' |' /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c
    # Compile
    cd /home/daniela/Downloads/nghttp2-1.34.0/examples && make
    # Run the program
    ./libevent-server 8010
    # Wait a bit before starting top
    sleep 10s
    # Top to get cpu and mem
    top -d 0,01 -b | grep lt-libevent-ser >> ${PARAMETER}$value.log &
    # Wait for the experiment to run
    sleep 1m
    # Kill the process
    ps -ef | grep libevent-server | grep -v grep | awk '{print $2}' | xargs kill
    sleep 5s
    # Kill top
    #ps -ef | grep top | grep -v grep | awk '{print $2}' | xargs kill
    # Remove old settings
    sed -e '/{NGHTTP2\_SETTINGS\_/d' -i /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c
done

