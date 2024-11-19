# Notes on setting up a ssh Reverse tunnel

basicNVR serves snapshot that are typically accessed by 
setting up "port forwarding" of port 9003 on the router that interfaces the Internet.   
Some ISP's cannot accept inbound connections. I expect it is improved security and keeps bad guys out.   
Our solution is to tunnel from the internal system to external system. 
so when you access port 9003 on your vps server it is  tunneled to basicNVR port 9003.   
this is done by setting up a ssh -Reverse tunnel   

See the help for ssh/OpenSSH
check to see if ssh is installed
```ssh you@192.168.8.1```

## we need to use "ssh Reverse" to get access
ssh -R allows the creation of a tunnel to a external server from our server

format of Reverse: ssh -R 80:192.168.1.10:8080 user@123.45.67.89

things to configure if it does not work out-of-the-box like a new install

we need to identify ourself 
first: put our identity on the external server 
      if this is not done ssh in time will attempt to reverify and want a keyed password.  hanging  ssl in a soft loop
Generate a system keyed, take defaults
```ssh-keygen```

now push it to the remote system
```ssh-copy-id jim@<remote ip address>```

that is all that is needed for short runing tasks.   

This needs to run forever... 

## "tunnel timed out" problem 
if the tunnel is open for a while, reverification is requested and fails 
It does not seem to use the same ssh-keygen stuff (might be ssh version problem)
so it searches other locations for some auth files in a never ending loop.
the fix is:
reverify is looking for: /root/.ssh/id_rsa among others
it should be there   
```ls -la /root/.ssh/id_rsa```
if not then copy it there from your .ssh directory
```cp .ssh/id_rsa /root/.ssh```

now the sshd_config port stuff
``` vi /etc/ssh/sshd_config```
in sshd_config uncomment and change no to yes
GatewayPorts no
to
GatewayPorts yes
I do this on BOTH systems

check external server  for external firewalls that may need to allow a port to be opened.
this can be detected if the test query runs on external server but not on others.
------------------------------------------------
end of known configurations, add more as found
-------------------------------------------------

now test and debug
 
this will be run a few times as you debug the whole configuration
```
sshpass -p <password> ssh -vNR 0.0.0.0:9003:localhost:9003  jim@<remote ip address>
```

when you have a clean ssh -- now test with simple query.

```curl http://<remote ip address>:9003```

if all this works as expected it can be run as a daemon
setting up a daemon is only after testing for hours. 
incomplete configuration causes ssh to go into a never ending loop   

Change the ssh to autossh see: [https://www.harding.motd.ca/autossh/]
#
Now create a .service file for systemd and place it here: 
```
/etc/systemd/system/autossh-vps-9003.service
```
note change "ExitOnForwardFailure=yes"  to "no" after you get it working
```
[Unit]
Description=Persistent tunnel from localhost port 9003 to <remote ip address> port 9003  (autossh)
After=network.target
[Service]
User=basicnvr
ExecStart=/usr/bin/sshpass -p remote-password /usr/bin/autossh -M 0 -o "ExitOnForwardFailure=yes"  -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -NR 0.0.0.0:9003:localhost:9003  jim@<remote ip address>
[Install]
WantedBy=multi-user.target
```

then activate it
```
systemctl daemon-reload
systemctl enable autossh-vps-9003.service
systemctl start autossh-vps-9003.service
```

test with ```curl http://<remote ip address>:9003```

tunnel shouild be installed an running now


## tools area
find prcesses on a socket
```
netstat --all --program | grep '9003'
netstat -lntn
```
good information here: [https://pesin.space/posts/2020-10-16-autossh-systemd/]   


when things break
```
sudo systemctl status   autossh-vps-9003.service
sudo systemctl start   autossh-vps-9003.service
sudo systemctl restart autossh-vps-9003.service
sudo systemctl daemon-reload
```







