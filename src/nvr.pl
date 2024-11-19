#!/usr/bin/perl -I /simplenvr
# MIT Licence Copyright 2017-2024 by James E Dodgen Jr.  MIT Licence.
#
# this is the cgi script that lives under apache (via a soft link) and provides the visualzation of the recored pictures
#
use strict;
use warnings;
#use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use database;
use HTML::Template;
#use QueueManager;
use File::Basename;
use watchdog;
use tools;
use Data::Dumper;
use html;
#use ip_tools;
#use tools;
use POSIX ":sys_wait_h";
use cfg;
#use favicon;

use constant DEBUG => 1;
print "Content-type: text/html\n\n";
if (! -e cfg::DBNAME)
{
	print "No database yet, try again in a minute";
	return;
} 

my ($method,%form) = parse_http_request();
process_request($method,%form);

sub process_request
{
    my ($method,%form) = @_;
    #my $vars= Dumper %form;
    #print("method[$method] form = $vars");
    my $remote_IP = $ENV{REMOTE_ADDR};
    if (!$method)
    {
        $method = 'video';
        #report_unauthorized_access($dt, $remote_IP);
    }

    if ($remote_IP)
    {
     printf STDERR "dvr:process_request: recieved a request from  %s\n", $remote_IP if DEBUG;
     #my $WorkerBeeQueue = QueueManager::WorkerBeeQueue();
     #$WorkerBeeQueue->enqueue({request => "DVR_ACTIVITY", ip => $remote_IP});
    }
    printf STDERR "dvr:process_request:  method=[%s]\n", $method||"Nothing parsed in"  if DEBUG;

    my $dt = database::open(cfg::DBNAME);

    if ($method =~ /^video/)
    {
        my $msg="";
        #### my ($state,$number) = split /\:/, $form{request};

        #$msg .= "Remote=$remote_IP local=$ip\n$vars camera_nbr=".($form{camera_nbr}||"none");
        my $t;
        print STDERR "dvr:process_request [$method]\n";

        if ($method =~ /^videoget/)
        {
              my $video_file_name;
              $t = HTML::Template->new_scalar_ref( html::view_video(),
                     ( xdebug => 1, xstack_debug => 1 ) );
              my ($videoget, $request, $tail) = split '\.', $method;
              printf STDERR "dvr:process_request: videoget request=[%s] tail [%s]\n", $request, $tail ;# if DEBUG;
              if ($request eq 'day' || $request eq 'hour')
              {
                  $video_file_name = get_concat_video_mp4($dt, $tail);
                  #my $mp4_name = basename($video_file_name);
                  $t->param(video => $video_file_name);
              }
              else # passed rowid
              {
                  $video_file_name = get_video_mp4($dt, $request);
                  print STDERR $video_file_name."\n";
                  $video_file_name =~ /simplenvr(.*)/;
                  $t->param(video => $1);
              }
              print $t->output;
              return;
        }
        $t = HTML::Template->new_scalar_ref( html::video_devices(),
                ( xdebug => 1, xstack_debug => 1 ) );
        $t->param(password => $form{password});
        my $config = tools::get_config($dt);
        ##  my  $ip = ip_tools::get_ip_addr($config, $WorkerBeeQueue);
        ## $t->param(ip_addr => $ip);
        if (exists $form{"Rebuild_database"})
        {
            watchdog::rebuildImageTable();
        }
        if (exists $form{delete_video})
        {
            delete_video($dt, $t, $form{delete_video}, $form{password});
            this_camera($dt,$t,$form{camera_nbr});
            if (! all_videos($dt,$t,$form{camera_nbr},$form{year}, $form{month}, $form{day}, $form{hour}))
            {
                if (! all_hours($dt, $t ,$form{camera_nbr}, $form{year}, $form{month}, $form{day}))
                {
                    if (! all_days($dt,$t,$form{camera_nbr},$form{year}, $form{month}))
                    {
                        if (! all_months($dt,$t,$form{camera_nbr}, $form{year}))
                        {
                            if (! all_years($dt, $t, $form{camera_nbr}))
                            {
                                all_cameras($dt, $t);
                            }
                        }
                    }
                }
            }
        }
        elsif (exists $form{select_camera})
        {
            this_camera($dt,$t,$form{select_camera});
            all_years($dt, $t, $form{select_camera});
        }
        elsif (exists $form{select_year})
        {
            this_camera($dt,$t,$form{camera_nbr});
            all_months($dt,$t,$form{camera_nbr}, $form{select_year});
        }
        elsif (exists $form{select_month})
        {
            this_camera($dt,$t,$form{camera_nbr});
            all_days($dt,$t,$form{camera_nbr},$form{year}, $form{select_month});
        }
        elsif (exists $form{select_day})
            {
            this_camera($dt,$t,$form{camera_nbr});
            all_hours($dt,$t,$form{camera_nbr},$form{year}, $form{month}, $form{select_day});
            }
        elsif (exists $form{select_hour})
            {
            this_camera($dt,$t,$form{camera_nbr});
            all_videos($dt,$t,$form{camera_nbr},$form{year}, $form{month}, $form{day}, $form{select_hour});
            }
        elsif (exists $form{state})
        {
            if ($form{state} eq 'Reset Hour')
            {
                this_camera($dt,$t,$form{camera_nbr});
                all_hours($dt,$t,$form{camera_nbr},$form{year}, $form{month}, $form{day});
                $msg .= "No Hour Selected";
        }
            elsif ($form{state} eq 'Reset Day')
        {
                this_camera($dt,$t,$form{camera_nbr});
                all_days($dt,$t,$form{camera_nbr},$form{year}, $form{month});
                $msg .= "No Day Selected";
            }
            elsif ($form{state} eq 'Reset Month')
            {
                this_camera($dt,$t,$form{camera_nbr});
                all_months($dt, $t, $form{camera_nbr},$form{year});
                $msg .= "Select a month";
            }
            elsif ($form{state} eq 'Reset Year')
            {
                this_camera($dt,$t,$form{camera_nbr});
                all_years($dt, $t, $form{camera_nbr});
                $msg .= "Select a year";
            }
            elsif ($form{state} eq 'Reset Camera')
            {
                all_cameras($dt, $t);
            }
        }
        else ####  if ($form{state} || $form{state} eq "Reset Camera")
        {
            print STDERR "dvr:process_request default, all cameras\n";
            all_cameras($dt, $t);
        }

        $t->param(msg => $msg);
        my $out=$t->output;
        $out =~ s/(^|\n)[\n\s]*/$1/g;
        print (tools::clean_html($out));
      }
    else #unknown method, might  be a hack in progress
    {
        report_unauthorized_access($dt, $remote_IP);
    }
}

sub report_unauthorized_access
{
    my ($dt, $remote_IP) = @_;
    my $now = time;
    my ($status, $last_date) = $dt->get_rec("SELECT date FROM wan_activity WHERE ip_addr = %s", $remote_IP);
    if ($status == 0)
    {
        $dt->do('INSERT into wan_activity (ip_addr, hits, date) VALUES (%s,%s,%s)', $remote_IP, 1, $now );
    }
    else
    {
         $dt->do('UPDATE wan_activity SET hits = hits + 1, date = %s WHERE ip_addr = %s', $now, $remote_IP);
    }
    print  "HTTP/1.0 200 OK\nContent-Type: text/html\n\n";
    print  "Unathorised access attempt: logged and reported: 18 U.S.C. &sect; 1030(a)(1)\n";
}

sub delete_video
{
    my ($dt, $t, $row_id, $password) = @_;
    my $valid = tools::get_config($dt)->{password}, 1;
    print STDERR "passwords $valid  $password\n";
    if (Crypt::Password::check_password($valid, $password))
    {
        my ($status, $video_file_name) = $dt->get_rec(
    'SELECT DISTINCT images.file_name
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE images.rowid = %s', $row_id);

        print STDERR "status = $status $video_file_name\n";
        if ($status)
        {
            $video_file_name =~ s/\/\//\//g; # clean excess slashes
            $dt->do("DELETE FROM images WHERE rowid = %s", $row_id);
            if (! unlink $video_file_name)
            {
                $t->param(error =>  "Could not remove file $video_file_name");
            }
        }
        else
        {
            $t->param(error =>  "row_id[$row_id] not found");
        }
    }
    else
    {
        $t->param(error => 'Invalid Password');
    }
}


sub this_camera
{
    my ($dt,$t,$camera_nbr) = @_;
    print STDERR "dvr:this_camera camera number $camera_nbr\n";
    my $cfg  = tools::get_config($dt);
    # my $ip_addr = ip_tools::get_ip_addr($cfg, $WorkerBeeQueue);
    my ($status, $camera_name) = $dt->get_rec(
    'SELECT DISTINCT cameras.camera_name
    FROM cameras
    WHERE cameras.camera_nbr = %s', $camera_nbr);


    $t->param(camera_nbr => $camera_nbr);
    $t->param(camera_name => $camera_name);
    #$t->param(wan_server =>  $ip_addr.":".$cfg->{wan_http_port});
}

sub all_years
{
    my ($dt, $t, $camera_nbr) = @_;
    my $qcamera_nbr=$dt->quote($camera_nbr);
    my @years = $dt->tmpl_loop_query(
    "SELECT DISTINCT images.year
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE cameras.camera_nbr = $qcamera_nbr
    ORDER BY images.year DESC",(qw (year)));

    if (! @years)
    {
        print STDERR "dvr::all_years: none found camera [$qcamera_nbr]\n";
        return 0;
    }
    print STDERR "dvr::all_years: SOME were foundcamera [$qcamera_nbr]\n";
    $t->param(select_year => 1);
    $t->param(years => \@years);
    return 1;
}

sub all_months
{
    my ($dt,$t,$camera_nbr,$year) = @_;

    my $qyear=$dt->quote($year);
    my $qcamera_nbr=$dt->quote($camera_nbr);

    my @months = $dt->tmpl_loop_query(
    "SELECT DISTINCT images.month
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE cameras.camera_nbr = $qcamera_nbr
    AND images.year = $qyear
    ORDER BY  images.month ASC",(qw (month)));

    if (! @months)
    {
        return 0;
    }
  $t->param(year => $year);
   $t->param(select_month => 1);
   $t->param(months => \@months);
   return 1;
}

sub all_days
{
    my ($dt,$t,$camera_nbr,$year, $month) = @_;

    my $qyear=$dt->quote($year);
    my $qcamera_nbr=$dt->quote($camera_nbr);
    my $qmonth=$dt->quote($month);
    printf STDERR "y=[%s] m[%s] cam[%s]\n", ,$year, $month, $camera_nbr;
    my @days = $dt->tmpl_loop_query(
    "SELECT DISTINCT images.day
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE cameras.camera_nbr = $qcamera_nbr
    AND images.year = $qyear
    AND images.month = $qmonth
    ORDER BY  images.day ASC",(qw (day)));

    if (! @days)
    {
        print STDERR "no days found\n";
        return 0;
    }
   $t->param(year => $year);
   $t->param(month => $month);
   $t->param(select_day => 1);
   $t->param(days => \@days);
   return 1;
}

sub all_hours
{
    my ($dt,$t,$camera_nbr,$year, $month, $day) = @_;

    my $qyear=$dt->quote($year);
    my $qcamera_nbr=$dt->quote($camera_nbr);
    my $qmonth=$dt->quote($month);
    my $qday=$dt->quote($day);

    my @hours = $dt->tmpl_loop_query(
    "SELECT DISTINCT images.hour
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE cameras.camera_nbr = $qcamera_nbr
    AND images.year = $qyear
    AND images.month = $qmonth
    AND images.day= $qday
    ORDER BY  images.hour ASC",(qw (hour)));


    if (! @hours)
    {
        return 0;
    }
    $t->param(year => $year);
    $t->param(month => $month);
    $t->param(day => $day);
    $t->param(select_hour => 1);
    $t->param(hours => \@hours);
    return 1;
}

sub all_videos
{
    my ($dt,$t,$camera_nbr,$year, $month, $day, $hour) = @_;

    my $qyear=$dt->quote($year);
    my $qcamera_nbr=$dt->quote($camera_nbr);
    my $qmonth=$dt->quote($month);
    my $qday=$dt->quote($day);
    my $qhour=$dt->quote($hour);

    my @videos = $dt->tmpl_loop_query(
    "SELECT DISTINCT images.rowid, cameras.camera_name, images.year, images.month, images.day, images.hour, images.minute
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE cameras.camera_nbr = $qcamera_nbr
    AND images.year = $qyear
    AND images.month = $qmonth
    AND images.day= $qday
    AND images.hour= $qhour
    ORDER BY  images.file_name ASC",(qw (rowid camera_name year month day hour minute)));

   #foreach my $v (@videos)
   #{
      #$v->{video} =~ s/\/\//\//g;  # motion adds a extra slash in places
   #}
    if (! @videos)
    {
        return 0;
    }
    $t->param(year => $year);
    $t->param(month => $month);
    $t->param(day => $day);
    $t->param(hour => $hour);
    $t->param(select_video => 1);
    $t->param(videos => \@videos);
    return 1;
}

sub get_video_mp4
{
    my ($dt,$rowid) = @_;
    my ($status, $video_file_name) = $dt->get_rec(
    'SELECT DISTINCT images.file_name
    FROM cameras
    JOIN images ON cameras.camera_nbr = images.camera_nbr
    WHERE images.rowid = %s', $rowid);

    printf STDERR "dvr::get_video check returned status =%s filename = [%s]\n", $status, $video_file_name ;#if DEBUG;
    if ($status)
    {
        $video_file_name =~ s/\/\//\//g;  # motion adds a extra slash in places     printf STDERR "dvr::get_video check returned status =%s filename = [%s]\n", $status, $video_file_name if DEBUG;
        #my $video_file_name_mp4 = $video_file_name;
        #$video_file_name_mp4 =~ s/\.avi/\.mp4/;
        #if (! -f $video_file_name_mp4) # need to convert
        #{
            #my $cmd = cfg::FFMPEG." -i $video_file_name -c:v libx264 $video_file_name_mp4 -hide_banner";
            #system($cmd);
            #print STDERR "\n".$cmd."\n";
        #}
        return $video_file_name;
    }
    return
}

sub load_mp4
{
    my ($video_file_name_mp4) = @_;
    my $mp4;
    if (-f $video_file_name_mp4)
    {
        printf STDERR "dvr::load_mp4: loading %s\n", $video_file_name_mp4 if DEBUG;
        open(my $f, $video_file_name_mp4) or warn "dvr::get_video could not open video file $video_file_name_mp4\n";
        undef $/;
        $mp4 = <$f>;
        close $f;
    }
    else
    {
        printf STDERR "dvr::load_mp4: loading frownFace\n" if DEBUG;
        $mp4 = frownFace::get();
    }
    return $mp4;
}


#sub get_video
#{
    #my ($dt,$rowid) = @_;
    ## first we get and validate the video file
    #my $video_file_name_mp4 = get_video_mp4($dt,$rowid);
    #if ($video_file_name_mp4)
    #{
        #my $video = load_mp4($video_file_name_mp4);
        #printf STDERR "dvr::get_video: size of %s is %s\n", $video_file_name_mp4, length($video) if DEBUG;
        #return $video;
    #}
    #return;
#}

sub get_concat_video_mp4
{
    my ($dt, $tail) = @_;
    # first we get and validate the video file
    printf STDERR "dvr::get_concat_video tail = %s \n", $tail||'?' if DEBUG;
    my ($camera_nbr, $year, $month, $day, $hour) = split /\-/, $tail;
    my ($status, $name) = $dt->get_rec(
    'SELECT camera_name
    FROM cameras
    WHERE cameras.camera_nbr = %s', $camera_nbr);

    printf STDERR "dvr::get_concat_video_mp4 check returned camera_number = %s status = %s camera_name = [%s]\n", $camera_nbr, $status, $name ;#if DEBUG;
    if ($status) # this one can be served
    {
        # now gather up the videos that match this
        my $base_file_name;
        my $path;
        my $pattern;
        if (!$hour)
        {
            $hour='*' ;
            $base_file_name = $name.'_'.$year.'_'.$month.'_'.$day;
            $pattern = cfg::MOTION_DIR.$camera_nbr.'/'.$year.'/'.$month.'/'.$day.'/*/*/*.mp4';
            $path = $camera_nbr.'/'.$year.'/'.$month.'/'.$day;
        }
        else
        {
            $base_file_name = $name.'_'.$year.'_'.$month.'_'.$day.'_'.$hour;
            $pattern = cfg::MOTION_DIR.$camera_nbr.'/'.$year.'/'.$month.'/'.$day.'/'.$hour.'/*/*.mp4';
            $path = $camera_nbr.'/'.$year.'/'.$month.'/'.$day.'/'.$hour;
        }
        my @files = sort (glob $pattern);

        print STDERR Dumper @files if DEBUG;
        printf STDERR "dvr::get_concat_video_mp4 concat pattern [%s]\n", $pattern  if DEBUG;
        #my $unique = $$;

        my $video_file_name = cfg::MOTION_DIR.$path."/$base_file_name.mp4";

        my $files_list = "/tmp/$base_file_name.txt";
        make_concat_mp4($video_file_name, $files_list, @files);

        my $html_file_name = cfg::WWW_VIDEO_DIR.$path."/$base_file_name.mp4";
        return $html_file_name;
    }
}


#sub get_concat_video
#{
    #my ($dt, $tail) = @_;
    #my $video_file_name = get_concat_video_mp4($dt, $tail);
    #open(my $f, $video_file_name) or warn "dvr::get_concat_video could not open video file $video_file_name\n";
    #undef $/;
    #my $video = <$f>;
    #close $f;
    #printf STDERR "dvr::get_concat_video size of %s is %s\n", $video_file_name, length($video) ;# if DEBUG;
    #return $video;
#}

sub make_concat_mp4
{
    my ($video_file_name, $files_list, @files) = @_;
    if (@files) # got some so lets merge/convert
    {
        if (-f $video_file_name)
        {
            my $merged_mod_time = (stat ($video_file_name))[9];
            my $newest_list_time =  (stat ($files[@files -1]))[9];
            if ($merged_mod_time > $newest_list_time)
            {
                return; # no need to create again
            }
        }
        open FILE, '>', $files_list or die "dvf::make_mp4 DIE Cannot open $files_list $!";
        foreach my $f (@files)
        {
            # print STDERR "dvr::get_concat_video saving file names $f\n"
            print FILE "file $f\n";
            # print FILE "file /dev/shm/next.jpg\n";
        }
        close FILE;
        #system("cfg::FFMPEG -v quiet -f concat -i $files_list -c copy $video_file_name");
        #my $cmd = cfg::FFMPEG."  -f concat  -safe 0 -i $files_list -vcodec libx264 -c copy $video_file_name.mp4".' -hide_banner -loglevel 0 ; '.cfg::FFMPEG." -i $video_file_name.mp4 -c:v libx264 $video_file_name -hide_banner  -loglevel 0 ";
        my $cmd = cfg::FFMPEG." -f concat  -safe 0 -i $files_list -c copy $video_file_name -hide_banner -loglevel 0";

        system($cmd);
        print STDERR $cmd."/n";
    }
}

sub all_cameras
{
    my ($dt, $t) = @_;
    my $cfg  = tools::get_config($dt);
    #my $ip_addr = ip_tools::get_ip_addr($cfg, $WorkerBeeQueue);
    #my $wan_server = $ip_addr.":".$cfg->{wan_http_port};
    my @video_cameras = $dt->tmpl_loop_query(
    "SELECT DISTINCT cameras.camera_nbr, cameras.camera_name, cameras.movie_output
    FROM cameras
    ORDER BY  cameras.camera_name ASC",(qw (nbr camera_name ffmpeg_output_movies)));

    $t->param( video_cameras => \@video_cameras);
}

sub get_request
{
    my $buffer;
    if ($ENV{'REQUEST_METHOD'} eq "POST")
    {
       read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    }
    else
    {
       $buffer = $ENV{'QUERY_STRING'};
    }
    # Split information into name/value pairs
    my @pairs = split(/&/, $buffer);
    my %form;
    foreach my $pair (@pairs)
    {
       my ($name, $value) = split(/=/, $pair);
       $value =~ tr/+/ /;
       $value =~ s/%(..)/pack("C", hex($1))/eg;
       $form{$name} = $value;
    }
   return %form;
}

sub parse_http_request
{
    my %form;

    my $method;
    printf STDERR ("nvr:parse_http_request:\n") if DEBUG;
    my $p;
    if (uc($ENV{'REQUEST_METHOD'}) eq "GET")
    {
        my $raw;
        ($raw, $p) = split( m/\?/, $ENV{'REQUEST_URI'} );
        if ($raw)
        {
            $raw  =~ s/%(..)/pack("C", hex($1))/eg ;
            $raw  =~ /\/nvr\/(.*)/;
            $method = $1;
        }
    }
    else ## must be POST
    {
        my $buffer;
        $ENV{'REQUEST_URI'} =~ /\/nvr\/(.*)/;
        $method = $1;
        read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
        printf STDERR "POST buffer [%s]<br>", $buffer;
        $buffer  =~ s/%(..)/pack("C", hex($1))/eg;

        #$buffer =~ m|\n(.*)$|;
        $p = $buffer;
        printf STDERR ("dvr:parse_http_request: post_string = [%s]\n", $p) if DEBUG;
    }
    printf STDERR ("parse_http_request:  method = [%s]\n", $method) if ($method && DEBUG);
    if ($p)
    {
        %form = parse_parms($p);
    }
    # print Dumper \%form;
    return ($method, %form);
}

sub parse_parms
{
    my %form;
    my ($p) = @_;
    my @parms = split( /&/, $p );

    foreach my $parm (@parms)
    {
        my ( $name, $value ) = split( /=/, $parm );
        $value .= "";
         printf STDERR ("dvr:parse_parms: [%s] =  [%s]\n", $name, $value) if DEBUG;

        $value =~ tr/+/ /;
        $value =~ s/%(..)/pack("C", hex($1))/eg;
        $name  =~ s/%(..)/pack("C", hex($1))/eg;
        if (exists $form{$name})
        {
           $form{$name} .= ",".$value;
        }
        else
        {
            $form{$name} = $value;
        }
    }
    return %form;
}


1;


