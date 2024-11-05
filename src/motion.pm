package motion;
# Copyright 2011, 2015 by James E Dodgen Jr.  MIT Licence

#for sv3c
#snapshot http://192.168.0.15/cgi-bin/hi3510/param.cgi?cmd=snap&-getpic

#rtsp://192.168.0.15:554/11
##ffmpeg -v 3 -vcodec mpeg4 -i rtsp://192.168.0.15:554/11 -y -vcodec copy -an /x.avi
# SIGHUP to have deamon reread config

use DBI;
use DBD::SQLite;
use POSIX ":signal_h";
use DBTOOLS;
use database;
use cfg;
#use Filesys::Df;
use Data::Dumper;
use strict;

#use tools qw (:debug);
use constant DEBUG => 0;


print "Debug on for motion\n" if DEBUG;

#my $dummy_motion_conf = <<EOF;
#log_level 8
## log_type DBG

#daemon off
#setup_mode off
#frequency 0
#framerate 1
#videodevice /dev/zero
#EOF





my $motion_conf = <<EOF;
log_level 4
# log_type EVT
#log_file /database/log.txt

daemon off
setup_mode off
frequency 0

framerate 6
minimum_frame_time 0
auto_brightness 0
roundrobin_frames 1
roundrobin_skip 1
roundrobin_switchfilter off
threshold 1500
threshold_tune off
noise_level 32
noise_tune on
despeckle_filter EedDl
smart_mask_speed 0
lightswitch_percent 100
minimum_motion_frames 4
pre_capture 1
post_capture 2
event_gap 60
movie_max_time 60
emulate_motion off

picture_output off

picture_output_motion off
picture_quality 75
v4l2_palette 17
picture_type jpeg

movie_output_motion off
timelapse_mode 0
timelapse_mode hourly
movie_bps 500000
movie_quality 0
movie_codec mp4
snapshot_interval 1
locate_motion_mode off
locate_motion_style box
text_right %Y-%m-%d\\n%T-%q
text_changes off
text_event %Y%m%d%H%M%S
text_scale 3
target_dir /
#picture_filename %v-%Y%m%d%H%M%S-%q
#movie_filename %v-%Y%m%d%H%M%S
timelapse_filename %Y%m%d-timelapse
webcontrol_ipv6 off
webcontrol_port 0
stream_port 0
track_type 0
track_auto off
track_motorx 0
track_motory 0
track_maxx 0
track_maxy 0
track_iomojo_id 0
track_step_angle_x 10
track_step_angle_y 10
track_move_wait 10
track_speed 255
track_stepsize 40
quiet on
sql_log_movie on
sql_log_picture off
sql_log_snapshot off
sql_log_timelapse off
database_type sqlite3
database_busy_timeout 1000
EOF

my $common_template = <<EOF;
camera_name %s
movie_output  %s
norm 1
input -1
rotate %s
width %s
height %s
text_event %s
text_left %s
movie_filename %s/%s
snapshot_filename %s/lastsnap
%s
EOF


my $movie_path = "%Y/%m/%d/%H/%M/%S";
my $dir = "/tmp/";
my $now;


sub task
{
    printf "motion:task: exec motion now\n" if DEBUG;
    #my $rc = system ('runuser -l www-data -c "/usr/local/bin/motion -c/tmp/motion.conf"');
    exec ('/usr/local/bin/motion', '-c/tmp/motion.conf');
}

sub create_motion_configs
{
    my ($dt) = @_;
    ### note: server value is set in http_processor
    my @cameras = $dt->tmpl_loop_query(<<EOF,
    SELECT camera_nbr, camera_name, server, ip_addr, port, user, password, options, 
    movie_output, motion_area_detect, rotate_image, COALESCE(width,640), COALESCE(height,480), 
    camera_template.netcam_url, camera_template.netcam_keepalive
    FROM cameras
    JOIN camera_type ON camera_type.name = cameras.server
    JOIN camera_template ON camera_type.tid = camera_template.tid
    WHERE (camera_name NOT NULL OR camera_name <> "") and (ip_addr NOT NULL OR ip_addr <> "")
EOF
          (qw(camera_nbr camera_name server ip_addr port user password options movie_output motion_area_detect rotate_image width height
               netcam_url netcam_keepalive)));

    if (@cameras)
    {
        # first build up motion.conf
        open MOTION_CONF, ">", $dir.'motion.conf' or die $!;
        print MOTION_CONF $motion_conf;
        printf MOTION_CONF "\ndatabase_dbname %s\n", cfg::DBNAME;
        foreach my $c (@cameras)
        {

            my $camera_name = $c->{camera_name};
            my $camera_nbr = $c->{camera_nbr};
            my $area_detect = '';
            if ($c->{motion_area_detect})
            {
                $area_detect = "area_detect ".$c->{motion_area_detect}."\non_area_detected /usr/bin/perl -I /alertaway /alertaway/motion_detected.pl $camera_nbr\n";
            }
            my $server = $c->{server};
            print "motion:create_motion_configs processing camera [$camera_name:$camera_nbr:$server]\n" if DEBUG;
            my $rotate_image = $c->{rotate_image} || 0;
            my $fileName = $camera_nbr.'/%Y%m%d%H%M%S';
            next if (!$camera_name || $camera_name eq '');
            my $thread_conf_path = $dir.$camera_nbr.'.conf';
            # now we write out the motion thread files
            $c->{movie_output} = $c->{movie_output}?'ON':'OFF';
            
		
			my $thread_text = sprintf  $common_template, $camera_name, $c->{movie_output}, $rotate_image, $c->{width}, $c->{height}, $camera_name,$camera_name,
				cfg::MOTION_DIR.$camera_nbr, $movie_path,cfg::SNAPSHOTS.$camera_nbr, $area_detect;
			
			$thread_text .= "netcam_keepalive ".$c->{netcam_keepalive}."\n";
			
			my $url = $c->{netcam_url};			
			$url =~ s/\%USER/$c->{user}/;
			$url =~ s/\%PWD/$c->{password}/;
			my $ip;
			if ($c->{port} eq 'default')
			{
				$ip = $c->{ip_addr};
			}
			else
			{             
				$ip = $c->{ip_addr}.":".$c->{port};
			}
			$url =~ s/\%IPADDR/$ip/;
			$thread_text .= "netcam_url ".$url."\n";
			
            print "motion:create_motion_configs thread\n: $thread_text\n";  #if DEBUG;
            printf MOTION_CONF "camera %s\n", $thread_conf_path;
            open THREAD, ">", $thread_conf_path or die;
            print THREAD $thread_text.<<EOF;
sql_query insert or ignore into images (camera_nbr, file_name, year, month, day, hour, minute) values ($camera_nbr, '%f', '%Y','%m','%d','%H','%M')
EOF
            close THREAD;
        }
        close MOTION_CONF;

        # now check to see if motion running if so then have it reread config else start it
        $dt->do("BEGIN exclusive transaction");

        my ($status, $motion_pid) = $dt->get_rec("select pid from motion");
        print("create_motion_configs have cameras motion pid [$motion_pid]\n");
        if ($motion_pid > 0)
        {
            kill (POSIX::SIGHUP, $motion_pid); # motion rereads configs
        }
        else
        {
            $motion_pid = fork;
            if ($motion_pid)  # in parent
            {
                printf "basicNVR: motion started ... >  %d\n", $motion_pid if DEBUG;
                $dt->do("update motion set pid = %s", $motion_pid);
            }
            else # IN FORKED CHILD
            {
                die "fork failed: $!" unless defined $motion_pid;
                motion::task();
                die "motion ended";
            }
        }
        $status = $dt->do("commit transaction")

    }
    else # no cameras found, so if motion running then kill it
    {
        $dt->do("BEGIN exclusive transaction");
        my ($status, $motion_pid) = $dt->get_rec("select pid from motion");

        print("create_motion_configs no cameras motion pid [$motion_pid]\n");
        if ($motion_pid > 0)
        {
            kill(POSIX::SIGINT, $motion_pid);
             $dt->do("update motion set pid = 0");
        }
        $status = $dt->do("commit transaction")
    }
}

sub forceSnapshots
{
    my ($dt) = @_;
    my ($status, $motion_pid) = $dt->get_rec("select pid from motion");
    if ($motion_pid > 0)
    {
        kill (POSIX::SIGALRM, $motion_pid);
    }
}



1;
