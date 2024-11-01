package cfg;
# Copyright 2020, 2021, 2024 by James E Dodgen Jr.  MIT licence
use strict;

use constant DBNAME  => '/database/basicNVR.db';
use constant FREEDISKSPACELOCK  => '/dev/shm/diskspace.lock';
use constant REBUILDIMAGETABLELOCK  => '/dev/shm/imagetable.lock';
use constant MOTION_DIR => '/var/www/basicNVR/motion/'; # full path
use constant WWW_VIDEO_DIR => "/motion/"; # used by cgi script dvr.pl
use constant FFMPEG => '/usr/bin/ffmpeg';
use constant SNAPSHOTS => '/dev/shm/snapshots/';
use constant DEFAULT_SERVER_PORT => 9000;
use constant SERVICE_PORT => 9002;
use constant EXTERNAL_PORT => 9003;
use constant TIMEDATECTL => "/usr/bin/timedatectl";
use constant FTP_SITE     => 'alertaway.com';
use constant FTP_USER     => 'xxx';
use constant FTP_PASSWORD => 'xxx';
use constant BASENAME => 'simplenvr';

# FTP/SSH stuff
use constant FTP_SITE     => 'basicNVR';    
use constant FTP_USER     => 'xxxx';
use constant FTP_PASSWORD => 'R1kxxxxjed';
use constant FTP_PORT     => 9005;

1;



