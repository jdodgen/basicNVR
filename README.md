# basicNVR a Simplified low overhead network video recorder
      
### Summary:

basicNVR is a lightweight Network Video Recorder (NVR) built around the popular [motion](https://motion-project.github.io/) repository.    
It simplifies recording and managing video streams from IP cameras.    
It offers features like:    
Motion detection recording    
File management with automatic deletion    
SQLite database for recording information    
User interface for simple browsing recordings, by date and time with video consolodation as requested.    
Admin interface for configuration    
HTTP API access for getting JPEGs (used by [AlertAway](https://github.com/jdodgen/MQTT-home/tree/main/linux/alertaway) for example)  

example system screen shots: [basicNVR.com](http://basicNVR.com)
   
### Current Status:

The system is currently running successfully for several years on an Intel J5005 machine with Ubuntu 18.04.   
It manages 7 PoE IP cameras.   
The website (basicNVR.com) is registered.    

### short term changes

SSH Tunnel check in watchdog.    
Improve url templates.

### Future changes:
Upgrade Motion.    
Implement pass-through streaming in motion (possibly using motionplus)     
Develop a tool (HTML) for creating "motion control masks"    
Add internal communication to MQTT in addition to current HTTP.     
Improve the user interface    
Design website content for basicNVR.com   

### Additional Notes:

This system has gone through several iterations, starting with USB webcams and coaxial CCTV cameras before transitioning to fully utilizing ONVIF/RTSP IP cameras.
Some legacy stuff can still be used but may go away.








 
