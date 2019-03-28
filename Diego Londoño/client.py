from __future__ import print_function
import psutil
import subprocess
import re

server=False
ip = "192.168.1.175:8084"
w="16"
filename = "nghttp_no-push_w"+w+"_m1.log"
with open(filename,'w') as filewriter:
        for i in range(1,68):
                print("running "+str(i))
                filewriter.write("running "+str(i)+"\n")
                
                nghttp = subprocess.Popen('nghttp https://nghttp2.org -nas --no-push --no-dep -w '+w+' -W '+w, stdout=subprocess.PIPE, shell=True)
                npid = nghttp.pid
                pnghttp = psutil.Process(npid)
                p=False
                q = True
                while nghttp.poll() is None:
                        for line in nghttp.stdout:
                                print(line)
                                filewriter.write(str(line))
exit()
