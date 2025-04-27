# tunnel test routine 
# MIT Licence 2025 jim dodgen

import urllib.request
import time
import os

url = "http://212.227.238.151:9003"
check_sleep_time = 60
wait_sleep_time = 30
broke_wait_time = 60*30
while True:
    try:
        while True:
            try:
                sock = urllib.request.urlopen(url) #, timeout=10)
            except:
                print("not found")
                time.sleep(wait_sleep_time)
            else:
                print("found")
            time.sleep(check_sleep_time)
    except:
         print("big fail")
         time.sleep(broke_wait_time)

