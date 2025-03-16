# this was needed because /etc/systemd/system/autossh-vps-9003.service does not restart on a reboot when network interupted.

import urllib.request
import time
import os

url = "http://212.227.238.151:9003"
check_sleep_time = 10
wait_sleep_time = 30
restart = "systemctl restart autossh-vps-9003.service"

while True:
    try:
        sock = urllib.request.urlopen(url, timeout=10)
    except:
        print("not found")
        time.sleep(wait_sleep_time)
        #os.system(restart)
    else:
        print("found")
    time.sleep(check_sleep_time)
