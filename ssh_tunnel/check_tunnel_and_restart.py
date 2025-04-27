# this was needed because /etc/systemd/system/autossh-vps-9003.service does not restart on a reboot when network interupted.
# MIT Licence 2025 jim dodgen
import urllib.request
import time
import os

url = "http://1.2.3.4:7000"
check_sleep_time = 60*60
wait_sleep_time = 60*4
broke_wait_time = 60*60*4
restart = "systemctl restart autossh-server.service"
while True:
    try:
        while True:
            try:
                sock = urllib.request.urlopen(url) #, timeout=10)
            except:
                #print("not found")
                time.sleep(wait_sleep_time)
                os.system(restart)
            time.sleep(check_sleep_time)
    except:
         print("big fail")
         time.sleep(broke_wait_time)

