package tools;
# Copyright 2011-2020 by James E Dodgen Jr.  All rights reserved.
# use threads::shared;
#use Storable;

use Net::SFTP::Foreign;
use Data::Dumper;
use DBTOOLS;
use strict;
use html_clean;
use feature 'state';
use cfg;

use constant DEBUG_ALL => 0;

use constant DEBUG_email => DEBUG_ALL;
use constant DEBUG_db => DEBUG_ALL;
use constant DEBUG_tools => DEBUG_ALL;
use constant DEBUG_XBeeXmitProcessor => DEBUG_ALL;
use constant DEBUG_HomeMonitor => DEBUG_ALL;
use constant DEBUG_WANserver =>  DEBUG_ALL;
use constant DEBUG_http_processor => DEBUG_ALL;
use constant DEBUG_LANserver => DEBUG_ALL;
use constant DEBUG_route_collection => DEBUG_ALL;
use constant DEBUG_IPcam => DEBUG_ALL;
use constant DEBUG_time_keeper => DEBUG_ALL;
use constant DEBUG_valve => DEBUG_ALL;
use constant DEBUG_process_packet => DEBUG_ALL;
use constant DEBUG_evaluate => DEBUG_ALL;
use constant DEBUG_motion_manager => DEBUG_ALL;
use constant DEBUG_processManager => DEBUG_ALL;

use constant DEBUG => DEBUG_tools;

sub how_long
{
    my ($now, $then) = @_;

    print "tools::how_long now = $now then = $then\n" if DEBUG;
    if ($then =~ m/^[0-9]+$/ && $now =~ m/^[0-9]+$/)
    {
        my $seconds = $now - $then;
        # print "....................................... how_long now = $now then = $then\n" if DEBUG;
        my $day = '';
        my $hour = '';
        my $minute = '';
        my $sec='';
        my $precision=0;
        if ($seconds >= 86400)
        {
            $day = sprintf "%d Days ", int($seconds / 86400);
            $seconds %= 86400;
            $precision++;
        }
        if ($seconds >= 3600)
        {
            $hour = sprintf "%d Hrs ", int($seconds / 3600);
            $seconds %= 3600;
            $precision++;
        }
        if ($seconds >= 60 && $precision < 2)
        {
           $minute = sprintf "%d Min ", int($seconds / 60);
           $seconds %= 60;
           $precision++;
        }
        if ($precision < 2)
        {
            $sec = $seconds.' sec';
        }
        return $day.$hour.$minute.$sec;
    }
    return 'Unknown';
}

my $config_cnt=999;
my $config_sth;
my $config_sql = <<EOF;
SELECT connection_type, wan_http_port, lan_http_port, camera_ip, static_ip, subnet_mask, gateway, dns1, dns2,
lw_connection_type, lw_wan_http_port, lw_static_ip, lw_subnet_mask, lw_gateway, lw_dns1, lw_dns2,
version_number, timezone, password,
dvr_user, dvr_password, ethernet_port, camera_ethernet_port, camera_subnet_mask
FROM config
EOF
my $values;

sub get_config
{
    my ($dt,$refresh) = @_;

    if ($config_cnt++ > 10 || $refresh)
    {
        $config_sth = $dt->query_prepare($config_sql);
        $config_cnt=0;
        my $status;
        ($status, $values) = $dt->get_rec_hashref_execute($config_sth);
        $values->{status} = $status;
        printf "tools:get_config: %s\n",  remove_nl(Dumper $values) if DEBUG;
    }
    return $values;
}

sub create_htpasswd
{
    my ($dt) = @_;
    system("/usr/bin/htpasswd -bc /database/htpasswd 'jed' 'Dairy.squal'");
    my $cfg = tools::get_config($dt);
    if ($cfg->{dvr_user} && $cfg->{dvr_password})
    {
        my $usr = trim($cfg->{dvr_user});
        my $pass = trim($cfg->{dvr_password});
        if ($usr gt '' &&  $pass gt '')
        {
            system("/usr/bin/htpasswd -b /database/htpasswd '$usr' '$pass'");
        }
    }
}

sub parse_http_request
{
    my ($request) = @_;
    my %form;
    printf("tools:parse_http_request: %s\n", $request) if DEBUG;
    my $method;
    if ( $request =~ m'^(GET|POST) /(.*) HTTP/1\.[01]' )
    {
       my $get_or_post = $1;
       my $get_string = $2;
       printf("tools:parse_http_request: get_or_post = %s\n", $get_or_post) if DEBUG;
       my $p;
       if (uc($get_or_post) eq "GET")
       {
           ( $method, $p ) = split( m/\?/, $get_string );
           $method  =~ s/%(..)/pack("C", hex($1))/eg if ($method);
       }
       else ## must be POST
       {
           $method = $get_string;
           $method  =~ s/%(..)/pack("C", hex($1))/eg;
           $request =~ m|\n(.*)$|;
           $p = $1;
          printf("tools:parse_http_request: post_string = [%s]\n", $p) if DEBUG;
       }
       printf("tools:parse_http_request:  method = [%s]\n", $method) if ($method && DEBUG);
       if ($p)
       {
           %form = parse_parms($p);
       }

    }
    # print Dumper \%form;
    return ($method, %form);

}

sub parse_parms
{
    my %form;
    my ($p) = @_;
    my @parms = split( /&/, $p );

    #printf("tools:parse_parms: parms array in @parms\n");
    foreach my $parm (@parms)
    {
        #printf("tools:parse_parms: parm[$parm]\n");
        my ( $name, $value ) = split( /=/, $parm );
        $value .= '';
         printf("tools:parse_parms: raw [%s] = [%s]\n", $name, $value) if DEBUG;

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
        printf("tools:parse_parms: [%s] => form value[%s]\n", $name , $form{$name}) if DEBUG;
    }
    #printf("tools:parse_parms: form out", dump_hash(\%form));
    return %form;
}

sub trim {
    my ($string) = @_;
    if (!defined($string))
    {
      return "";
    }
    $string  =~  s/^\s+//;
    $string  =~  s/\s+$//;
    if ($string eq "")
    {
        return "";
    }
    return $string;
}

sub clean_html
{
    my ($text) = @_;
    # print "tools::clean_html called\n";
    my $h = new html_clean(\$text);
    $h->strip(whitespace => 1, comments => 1);
    return ${$h->data()};
}

sub remove_nl
{
    my ($l) = @_;
    $l =~ s/\n//g;
    $l =~ s/\s+/ /g;
    return $l;
}

sub location_string
{
    my ($location, $addr_low) = @_;
    $location = trim($location);
    if (!$addr_low)
    {
        $location = 'ID-'.substr(sprintf ("%0X", $location), -4);
    }
    elsif ($location eq '' ||  $location eq 'UNK')
    {
        $location = 'ID-'.substr(sprintf ("%0X", $addr_low), -4);
    }
    return $location;
}

#sub validate_part_nbr  # returns the part number, UNK or undef
#{
    #my ($dt, $WorkerBeeQueue, $part_nbr_in) = @_;
    #my $part_nbr;
    #if (!$part_nbr_in) {
        #$part_nbr = "UNK";
    #} else {
       #(my $status, $part_nbr) = $dt->get_rec('select part_nbr from device_types where part_nbr = %s', $part_nbr_in);
       #if ($status > -1 ) {
           #my $part_number_dump = unpack "H*", $part_nbr_in;
           #$WorkerBeeQueue->enqueue({request => "LOG", fmt => "Unknown device part-nbr %s", parms => [$part_number_dump]});
           #undef $part_nbr;
       #}
    #}
    #return $part_nbr;
#}

sub bigger_on_left
{
    my ($a, $b) = @_;
    if ($a > $b) {
        return $a.','.$b;
    }
    return $b.','.$a;
}

sub urlencode {
    my $s = shift;
    $s =~ s/ /+/g;
    $s =~ s/([^A-Za-z0-9\+-])/sprintf("%%%02X", ord($1))/seg;
    return $s;
}

sub urldecode
{
    my $s = shift;
    $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $s =~ s/\+/ /g;
    return $s;
}

sub hexDumper
{
    my ($name, $item, $not_first_time) = @_;
    my $string = '';
    return _hexDumperRecursion($string, $name, $item, $not_first_time);
}


sub _hexDumperRecursion
{
    my ($string, $name, $item,) = @_;
    my $type = ref($item);
    #printf Dumper $item;
    #printf ">>>  [%s] [%s] type [%s]\n", $name, $item, $type;
    if ($type eq 'HASH')
    {
        #print "Processing a HASH [$type]\n";
        foreach my $h (sort (keys (%$item)))
        {

            #printf "processing HASH item key[%s] value[%s] type[%s]\n",  $h, $item->{$h}, ref($item->{$h});
            if (ref($item->{$h}))
            {
                $string = _hexDumperRecursion($string, "$name->$h", $item->{$h});
            }
            else
            {
                 $string = _hexDumperRecursion($string, "$name->$h", \$item->{$h});
            }
        }

    }
    elsif ($type eq 'ARRAY')
    {
        #print "doing array $item\n";
        my $i = 0;
        foreach my $a (@$item)
        {
            #printf "processing array item [$a] %s\n", ref($a);
            if (ref($a))
            {
                 $string = _hexDumperRecursion($string, "$name\@$i", $a);
            }
            else
            {
                 $string = _hexDumperRecursion($string, "$name\@$i", \$a);
            }
            $i++;
        }
    }
    elsif ($type eq "SCALAR")
    {
        if (! defined($$item))
        {
            $string .= sprintf "%s[undef]\n", $name;
        }
        elsif ($$item =~ /^\d+$/)
        {
            $string .= sprintf "%s[%X]\n", $name, $$item;
        }
        elsif ($$item  =~ /^[\x20-\x7E]*$/)
        {
            $string .= sprintf "%s[%s]\n", $name, $$item;
        }
        else
        {
            $string .=  sprintf "%s[%s]\n", $name, unpack( 'H*', $$item);
        }
    }
    else
    {
        $string .= $$item;
    }
    return $string;
}

sub midnight # epoch at last midnight
{
    my ($now) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);
    return $now - ($sec + (($min + ($hour * 60)) * 60));
}

#use constant A_LONG_TIME => 24*60*60*365;   # a year
#use constant DAY_SECONDS => 24*60*60;
#sub get_next_timed_event_change
#{
    #my ($dt, $now, $device_rowid) = @_;
    #my $midnight = midnight($now); # epoch last midnight

    #my $next_change = A_LONG_TIME+$now;
    #my $this_day_of_week = (localtime($now))[6]; # returns 0-6
    ##printf "today is %s\n", $this_day_of_week;
    ## build day of week hash
    #my %days;
    #my $i=7;
    #my $j=0;
    #while ($i--)
    #{
        ##printf "this_day_of_week %s:%s i %s\n", $this_day_of_week, $this_day_of_week-7, $i;
        #if ($this_day_of_week > 6)
        #{
            #$days{$this_day_of_week-7}{i} = $i;
            #$days{$this_day_of_week-7}{displacement} = $j*DAY_SECONDS;
        #}
        #else
        #{
            #$days{$this_day_of_week}{i} = $i;
            #$days{$this_day_of_week}{displacement} = $j*DAY_SECONDS;
        #}
        #$this_day_of_week++;
        #$j++;
    #}
    ##print Dumper \%days;
    #my $clean_rowid = $dt->quote($device_rowid);
    ##printf "cleaned row_id [%s]\n", $clean_rowid;
    #my @timed_events = $dt->tmpl_loop_query(<<EOF, qw(days seconds_from_midnight duration));
    #SELECT timed_events.days, timed_events.seconds_from_midnight, timed_events.duration
    #FROM devices
    #JOIN timed_events ON devices.ah = timed_events.ah
     #AND devices.al = timed_events.al
     #AND devices.port = timed_events.port
    #WHERE devices.rowid = $clean_rowid
#EOF
    #foreach my $d (@timed_events)
    #{
        ##print "processing timed_evens\n";
        #foreach my $day (split ",", $d->{days})
        #{
            #my $might_work;
            #my $start_epoch = $d->{seconds_from_midnight} + $midnight + $days{$day}{displacement};
            ##printf "  day = [%s:%s]  checking start time %s > %s\n", $day, $days{$day}{i},  scalar localtime($start_epoch) ,scalar localtime($now);
            #if ($start_epoch > $now)  # before next start time
            #{
               ##print "     before next start time\n";
               #$might_work = $start_epoch;
            #}
            #elsif ($start_epoch + $d->{duration} > $now)  # or befor next end time
            #{
               ##print "     before next stop time\n";
               #$might_work = $start_epoch + $d->{duration};
            #}
            ##printf "     mightwork = %s next_change = %s\n", $might_work||'?', $next_change;
            #if ($might_work && $might_work < $next_change)
            #{
                ##printf ">>> found an earlier day %s < %s\n", scalar localtime($next_change) ,scalar localtime($might_work);
                #$next_change = $might_work;
            #}
        #}
    #}
    #return $next_change;
#}

#sub seconds_from_midnight
#{
    #my ($minutes, $hours) = @_;
    #return (($minutes + ($hours * 60)) * 60);
#}
#sub remove_override
#{
    #my ($dt, $rowid) = @_;
    #my $status = $dt->do(<<EOF, $rowid );
        #UPDATE devices
          #SET override_state = NULL, override_expire_time = NULL
          #WHERE rowid = %s
#EOF
#}

sub is_trace
{
    my ($hash, $al) = @_;
    if (($al && $hash->{$al}) || $hash->{DEBUG})
    {
        return 1;
    }
    return 0;
}

sub hash_trace
{
    my %hash;
    my ($str, $debug) = @_;
    if ($debug)
    {
       $hash{DEBUG} = 1;
    }
    else
    {
       $hash{DEBUG} = 0;
    }
    foreach my $al (split /,/, $str)
    {
        $hash{$al} = 1;
    }
    return %hash;
}

sub dump_hash
{
    my ($hash) = @_;
    while ( my ($k,$v) = each %$hash ) {
        print "$k => $v\n";
    }
}

#
#
# test code
#
#
#use db;
#my $dt = db::open(cfg::DBNAME);
#printf "next change time 8 = %s\n", scalar localtime(get_next_timed_event_change($dt,time,8));

sub connect_to_sftp
{
    my ($from_who) = @_;
    my $sftp;
    eval
    {
        $sftp = Net::SFTP::Foreign->new(cfg::FTP_SITE,
                        user => cfg::FTP_USER,
                        password => cfg::FTP_PASSWORD,
                        port => cfg::FTP_PORT,
                        more => [-o => 'StrictHostKeyChecking no']);
    };
    if ($@)
    {
       printf("sftp connect/new problem [%s] called by [%s]", $@, $from_who);
       #system "ssh-keygen -R ".FTP_SITE;
       return;
    }
    #printf("using FTP site = %s\n", cfg::FTP_SITE);
    return $sftp;
}
1;
