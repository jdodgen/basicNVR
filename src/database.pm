package database;
# Copyright 2011 - 2015 by James E Dodgen Jr.  All rights reserved.

use DBI;
use DBTOOLS;
use strict;
use Carp;
use IO::Compress::Gzip;
use Data::Dumper;

#use tools qw (:debug);
#use constant DEBUG => tools::DEBUG_db;

#printf "testing debug\n" if DEBUG;
use constant CURRENT_VERSION => 3;

sub open
{
    my ($dbname,$commit) = @_;

    my %sqlite_attr = (
    PrintError => 1,
    RaiseError => 0,
    ShowErrorStatement => 1,
    AutoCommit => defined $commit?0:1
    );
    #print "sqlite open ".$sqlite_attr{AutoCommit};
    my $dbh = DBI->connect( "dbi:SQLite:$dbname", "", "", \%sqlite_attr );
    if ( !defined($dbh) )
    {
        confess("could not connect to $dbname");
    }
    #$dbh->trace(2);
    #$dbh->{HandleError} = sub { confess(shift) };
    my $dt = new DBTOOLS( dbh => $dbh, xtrace => 1 );
    return $dt;
}

my $tables = <<EOF;

drop table if exists cameras;
CREATE TABLE cameras (
camera_nbr INTEGER PRIMARY KEY,
camera_name CHAR UNIQUE,
server CHAR NOT NULL,
ip_addr CHAR DEFAULT NULL,
port CHAR DEFAULT NULL,
user CHAR DEFAULT NULL,
password CHAR DEFAULT NULL,
wan_access CHAR(1) DEFAULT NULL,
sql_log_movie,
sql_log_picture,
sql_log_snapshot,
sql_log_timelapse,
lightswitch,
width,
height,
max_changes,
max_movie_time,
snapshot_interval,
stream_port,
netcam_keepalive,
motion_threshhold,
motion_noise_level,
motion_area_detect,
motion_mask_file,
minimum_motion_frames,
picture_output,
movie_output,
timelapse_interval,
rotate_image,
options CHAR
);

drop table if exists images;
CREATE TABLE images (
camera_nbr,
file_name,
year,
month,
day,
hour,
minute,
PRIMARY KEY (camera_nbr, file_name)
);
CREATE INDEX imagesx1 ON images (camera_nbr, year, month, day, hour, minute);

drop table if exists motion_mask;
CREATE TABLE motion_mask (
camera_nbr INTEGER PRIMARY KEY,
row,
col
);

/* sql_query insert or ignore into images (camera_nbr, file_name, year, month, day, hour) values (camera_nbr, '%f',%Y,%m,%d,%H,%M') */

drop table if exists config;
CREATE TABLE config (

primary_contact CHAR DEFAULT NULL,
connection_type CHAR DEFAULT NULL,
wan_http_port INTEGER DEFAULT NULL,
camera_ip CHAR DEFAULT NULL,
static_ip CHAR DEFAULT NULL,
subnet_mask CHAR DEFAULT NULL,
gateway CHAR DEFAULT NULL,
dns1 CHAR DEFAULT NULL,
dns2 CHAR DEFAULT NULL,
lw_connection_type CHAR DEFAULT NULL,
lw_wan_http_port INTEGER DEFAULT NULL,
lw_static_ip CHAR DEFAULT NULL,
lw_subnet_mask CHAR DEFAULT NULL,
lw_gateway CHAR DEFAULT NULL,
lw_dns1 CHAR DEFAULT NULL,
lw_dns2 CHAR DEFAULT NULL,
lan_http_port INTEGER DEFAULT 9001,
version_number INTEGER DEFAULT NULL,
default_email char default null,
timezone CHAR,
password,
network_address INTEGER,
dvr_user,
dvr_password,
ethernet_port,
camera_ethernet_port,
camera_ip,
camera_subnet_mask
);

drop table if exists wan_activity;
CREATE TABLE wan_activity (
ip_addr CHAR NOT NULL  PRIMARY KEY,
hits INTEGER DEFAULT NULL,
date INTEGER DEFAULT NULL
);

drop table if exists trusted_ip;
CREATE TABLE trusted_ip (
ip CHAR PRIMARY KEY
);


drop table if exists camera_type;
CREATE TABLE camera_type (
name PRIMARY KEY,
tid INTEGER
);

drop table if exists camera_template;
CREATE TABLE camera_template (
tid INTEGER PRIMARY KEY,
netcam_url,
netcam_keepalive
);
EOF

sub create_tables
{
    my ($dt) = @_;

    print "creating tables ...\n";
    my $errors = $dt->do_a_block($tables);
    $errors += $dt->do_a_block(<<EOF);

insert into config (connection_type, lw_connection_type, lan_http_port, wan_http_port)
values ("DHCP","DHCP",9002,9003);
EOF
    if ( $errors > 0 )
    {
        printf "found %d errors during db create\n", $errors;
    }
}

sub known_cameras
{
	my ($dt) = @_;
	$dt->do_a_block(<<EOF);	

	insert into camera_template (tid, netcam_url, netcam_keepalive) values (1, "http://%IPADDR/videostream.cgi?user=%USER&pwd=%PWD", "on");
	insert into camera_type (name, tid) values ("Foscam", 1);
	insert into camera_template (tid, netcam_url, netcam_keepalive) values (2, "rtsp://%USER:%PWD@%IPADDR/cam/realmonitor?channel=1&subtype=0", "off");
	insert into camera_type (name, tid) values ("Amcrest", 2);
	insert into camera_type (name, tid) values ("SV3C", 2);
	insert into camera_template (tid, netcam_url, netcam_keepalive) values (3, "http://%IPADDR/cgi-bin/CGIProxy.fcgi?cmd=snapPicture2&usr=%USER&pwd=%PWD", "off");
	insert into camera_type (name, tid) values ("FoscamHD", 3);
	insert into camera_template (tid, netcam_url, netcam_keepalive) values (4, "http://%USER:%PWD@%IPADDR/cgi/jpg/image.cgi", "off");
	insert into camera_type (name, tid) values ("TRENDnet", 4);
EOF
}

sub apply_patch
{
    my ($dt) = @_;
    #return;  # remove to use
    if (see_if_patch_needed($dt, 'camera_type', 'tidxxx'))
    {           
        my $errors = $dt->do_a_block(<<EOF);
drop table if exists camera_type;
CREATE TABLE camera_type (
name PRIMARY KEY,
tid INTEGER
);

drop table if exists camera_template;
CREATE TABLE camera_template (
tid INTEGER PRIMARY KEY,
netcam_url,
netcam_keepalive
);
EOF
	known_cameras($dt);
    }

}

sub see_if_patch_needed
{
    my ($dt, $table, $col) = @_;
    my ($status, $junk) = $dt->get_rec("select type from sqlite_master where type = 'table' and tbl_name  = %s and sql like %s",
               $table, '%'.$col.'%');
    printf "db:see_if_patch_needed: table [%s] field = [%s] needed? %s\n", $table, $col, $status?'NO':'yes';# if DEBUG;
    return !$status;
}

sub create_if_needed
{
    my ($db_name) =  @_;
    my $dt;
    if (-f $db_name)
    {
        $dt = database::open($db_name);
        print "create_if_needed database found\n";
        apply_patch($dt);
    }
    else
    {
        $dt = database::open($db_name);
        print "create_if_needed New database created\n";
        create_tables($dt);
    }
    print("create_if_needed initializing motion pid\n");
    my $errors = $dt->do_a_block(<<EOF);
drop table if exists motion;
CREATE TABLE motion (pid INTEGER);
insert into motion (pid) values(0);
EOF

my($status, $pid) = $dt->get_rec("select pid from motion");
printf("create_if_needed motion status[%s] pid[%s]\n", $status, $pid);
}

1;
