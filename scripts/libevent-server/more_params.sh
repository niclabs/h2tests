#!/bin/bash
# Ask user for number of parameters
echo -n "Enter number of parameters (0-6): "
read NUMBER
# Check that a number was entered (TODO number between 0 and 6)
if ! [[ "$NUMBER" =~ ^[0-9]+$ ]]
    then
        echo "Sorry integers only"
fi

_number="$NUMBER"

# Receive parameters
for  ((i=0;i<$NUMBER;i++)); 
do
	let "n=i+1"
	echo -n "Parameter name $n: "
	read PARAMETERS[$i] 
done

for i in ${PARAMETERS[@]}
do
   echo $i # or do whatever with individual element of the array
done

# Receive parameters values
for  ((i=0;i<$NUMBER;i++));
do
		echo -n "Values for the parameter ${PARAMETERS[i]}: "
		read VALUES[$i]
done

for i in ${VALUES[@]}
do
   echo $i # or do whatever with individual element of the array
done

# Go to server file

# Search for this line and remove parameter
sed -i 's|{NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS, 100}};|};|' /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c

# Replace number of parameters
#sed -i 's|nghttp2_settings_entry\ iv\[.]\ =\ {|nghttp2_settings_entry iv['"$NUMBER"'] = {|' /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c

# Remove old settings
sed -e '/{NGHTTP2\_SETTINGS\_/d' -i /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c

# Create a string with the new settings (include line breaks)
start='{'
middle=', '
end='}, '
bl='\n'

	for  ((i=0;i<$NUMBER;i++));
do
	# Concatenate parameters
	settings=${settings}${start}${PARAMETERS[i]}${middle}${VALUES[i]}$end$bl
	# Look for the line where to put the settings and add them
done

# Add settings
sed -i 's|nghttp2_settings_entry\ iv\[.]\ =\ {|nghttp2_settings_entry iv['"$NUMBER"'] = {\n'"$settings"' |' /home/daniela/Downloads/nghttp2-1.34.0/examples/libevent-server.c
# Compile
cd /home/daniela/Downloads/nghttp2-1.34.0/examples && make;
# Run the program
./libevent-server 8010
done

# make
# run experiments for three minutes or a little more

