package http_lan;
# Copyright 2011,2012,2024 by James E Dodgen Jr.  MIT Licence
use Data::Dumper;
use IO::Socket;
use HTML::Template;
use html;
use POSIX ":signal_h";
use POSIX ":sys_wait_h";
use strict;
use cfg;
##use Filesys::Df;
use tools;
use ip_tools;
use current_version;
use system_load;
use version;

use constant DEBUG => 1;
use constant FRESH_READ => 1;
use Crypt::Password;
my $message;

sub process
{
    my ($method, $dt, $now, $main_pid, %form) = @_;
    $message = '';
    my $t;
    my $menu_submit;
    my ($status, $timezone) = $dt->get_rec("SELECT timezone from config");
    #printf "http_lan: method [%s], form = %s\n", $method, Dumper \%form;
    if (!$timezone || $timezone eq '')
    {
       $message = 'Timezone must be set first<br>';
       ($t,$menu_submit) = set_timezone($dt, $now,%form);
    }
    elsif ($method eq "date")
    {
       ($t,$menu_submit)=set_timezone($dt, $now,%form);
    }
    elsif ($method eq "configuration")
    {
        ($t,$menu_submit)=config($dt, $now, %form);
    }
    elsif ($method eq "template")
    {
        ($t,$menu_submit)=template($dt, $now, %form);
    }
    #elsif ($method eq "motion_mask")
    #{
        #($t,$menu_submit)=motion_mask($dt, %form);
    #}
    elsif ($method eq "main")
    {
        ($t,$menu_submit)=cameras($dt,$now, %form);
    }
    $t->param( msg => $message) if ($t);
    return ($t,$menu_submit);
}

sub config
{
    my ($dt, $now, %form) = @_;
    my $passmsg;
     my $msg;


    my $prior_cfg;
    #printf "http_processor:config: $$ just entered config %s\n", Dumper \%form;
    if ($form{state})
    {
        $prior_cfg = tools::get_config($dt,FRESH_READ);
        #my $y = tools::get_config($dt,FRESH_READ);
        #printf "\n<<< cfg before update >>>\n";tools::dump_hash($y);
        if ( $form{state} eq "Update")
        {
            my $sql = <<EOF;
            UPDATE config SET connection_type = %s, lan_http_port = %s, wan_http_port = %s,
            camera_ip = %s, camera_subnet_mask = %s, static_ip = %s, subnet_mask = %s, gateway = %s, dns1 = %s, dns2 = %s,
            dvr_user = %s, dvr_password = %s
EOF

            my $status = $dt->do($sql,
                $dt->trim($form{"CONFIG:contype"}),  $dt->trim($form{"CONFIG:lanport"}),$dt->trim($form{"CONFIG:wanport"}),
                $dt->trim($form{"CONFIG:cameraip"}), $dt->trim($form{"CONFIG:cameramask"}), $dt->trim($form{"CONFIG:ip"}), $dt->trim($form{"CONFIG:mask"}),  $dt->trim($form{"CONFIG:gw"}),
                $dt->trim($form{"CONFIG:dns1"}), $dt->trim($form{"CONFIG:dns2"}), $dt->trim($form{"CONFIG:dvruser"}), $dt->trim($form{"CONFIG:dvrpass"}));
            my $x = tools::get_config($dt,FRESH_READ);
            #print "\n<<< cfg after update >>>\n";tools::dump_hash($x);

            tools::create_htpasswd($dt);
            if ($form{"CONFIG:password"})
            {
                if ($form{"CONFIG:password"} ne $form{"CONFIG:password_again"})
                {
                    $passmsg = "Passwords do not match";
                }
                else
                {
                     my $digest = Crypt::Password::password($form{'CONFIG:password'});
                     $dt->do("UPDATE config SET password = %s", $digest);
                     printf "http_processor:config:digest [%s]\n", $digest if DEBUG;
                     $passmsg = "Password set";
                }
            }
        }
        elsif ($form{state} eq "Add Trusted IP")
        {
            if ($form{"CONFIG:newtrustedip"})
            {
                my $tip = $dt->trim($form{"CONFIG:newtrustedip"});
                $msg .= check_ip_address($tip,"Trusted IP");
                if (! $msg)
                {
                    my $status = $dt->do("INSERT OR REPLACE INTO trusted_ip (ip) VALUES (%s)", $tip);
                }
            }
        }
        elsif ( $form{state} =~ /^Remove Trusted IP\s*(\d*)/ )
        {
            my $rowid = $1;
            $dt->do( "delete from trusted_ip where rowid =  %s", $rowid );
        }
        elsif ( $form{state} eq 'Check for updated software' )
        {
            my $cv = current_version::get();
            #my $status = $dt->do("update config set version_number = %s", $cv);
            if ($cv > version::VERSION())
            {
                $msg .= 'A newer version of the software is available (v '.$cv.')<br>Press "Restart" to install';
            }
            else
            {
                $msg .= "You are using the latest version<br>";
            }
        }
        elsif ( $form{state} eq "Restart" )
        {
            my $t = HTML::Template->new_scalar_ref( html::restartMsg(),
            ( xdebug => 1, xstack_debug => 1 ) );
            return ($t,"restart");

        }

    }
    my $t = HTML::Template->new_scalar_ref( html::configuration(),
            ( xdebug => 1, xstack_debug => 1 ) );

    my @tips = $dt->tmpl_loop_query("SELECT rowid, ip FROM trusted_ip ORDER BY ip",( "rowid", "ip"));
    $t->param(trustedips => \@tips );

    my $cfg = tools::get_config($dt,FRESH_READ);
    my $ip_errors;
    $ip_errors .= check_ip_address($cfg->{static_ip},"Static IP");
    $ip_errors .= check_ip_address($cfg->{camera_ip},"Camera IP");
    $ip_errors .= check_ip_address($cfg->{camera_subnet_mask},"Camera subnet_mask");
    $ip_errors .= check_ip_address($cfg->{subnet_mask},"Subnet Mask");
    $ip_errors .= check_ip_address($cfg->{gateway},"Gateway");
    $ip_errors .= check_ip_address($cfg->{dns1},"DNS1");
    $ip_errors .= check_ip_address($cfg->{dns2},"DNS2");
    $msg .= $ip_errors;
    if (!$passmsg)
    {
        if ($cfg->{password})
        {
            $passmsg = "Password on file";
        }
        else
        {
            $passmsg = "No password on file";
        }
    }
    $t->param( passmsg => $passmsg);

    my $needed_connection_type = $cfg->{connection_type};
    my $is_good_static = 1;
    if ($ip_errors # one or more are bad so cannot use them to set a static IP address
        ||
          ($dt->trim($cfg->{static_ip})   eq ""  ||
           $dt->trim($cfg->{subnet_mask}) eq ""  ||
           $dt->trim($cfg->{gateway})     eq ""  ||
           $dt->trim($cfg->{dns1})        eq ""))
    {
        $is_good_static = 0;
        $needed_connection_type = "DHCP";   # will not work as static
    }

    if ($cfg->{connection_type} ne $needed_connection_type)
    {
        $cfg->{connection_type} = $needed_connection_type;
        $dt->do("UPDATE config SET connection_type = %s", $needed_connection_type);
        $message .= "No valid static IP information, DHCP rules inforced<br>";
    }

    # now we need to check and see if we should attempt to change the network connection

    if ($prior_cfg)  # we did a update, something could have changed
    {
        if ($cfg->{connection_type} eq $prior_cfg->{connection_type} &&
			$prior_cfg->{camera_subnet_mask} eq  $cfg->{camera_subnet_mask} &&
            $prior_cfg->{camera_ip} eq  $cfg->{camera_ip} && 
			$cfg->{connection_type} eq 'DHCP') # no change in type
        {
             # fine leave things alone, nothing to do
        }
        elsif ($cfg->{connection_type} eq 'DHCP')  # looks like we have changed from static to DHCP, pretty safe
        {
            ip_tools::set_ip($dt); # ok change it to DHCP, about as safe as it gets
        }
        elsif ($is_good_static == 1)  # we have a static IP passed muster
        {
           # print Dumper $prior_cfg;
           # now before we apply this new address we should save away the working address
           # first check to see if anything changed
           if ( $prior_cfg->{connection_type} eq  $cfg->{connection_type} &&
                $prior_cfg->{dns1} eq  $cfg->{dns1} &&
                $prior_cfg->{dns2} eq  $cfg->{dns2} &&
                $prior_cfg->{static_ip} eq  $cfg->{static_ip} &&
                $prior_cfg->{subnet_mask} eq  $cfg->{subnet_mask} &&
                $prior_cfg->{camera_subnet_mask} eq  $cfg->{camera_subnet_mask} &&
                $prior_cfg->{camera_ip} eq  $cfg->{camera_ip} &&
                $prior_cfg->{gateway} eq  $cfg->{gateway})
           {
               # they are the same, ok do nothing
           }
           else # different, so save, apply and test
           {
               my $status = $dt->do(<<EOF, $prior_cfg->{connection_type},$prior_cfg->{wan_http_port},$prior_cfg->{static_ip},$prior_cfg->{subnet_mask},$prior_cfg->{gateway},$prior_cfg->{dns1},$prior_cfg->{dns2});
               UPDATE config SET lw_connection_type = %s, lw_wan_http_port = %s, lw_static_ip = %s,
                      lw_subnet_mask = %s, lw_gateway = %s, lw_dns1 = %s, lw_dns2 = %s
EOF
               # now we can can change the connection and test to see if it worked
               my $fell_back = ip_tools::set_ip($dt); # ok change it,
               if ($fell_back == 1) # does not look like the address is very good
               {
                   $message .= "This set of static IP address information does not work, reverted to prior values<br>";
               }
               else
               {
                   print "new address worked\n" if DEBUG;
                   # it worked so, make it the (lw) last working
                   $dt->do(<<EOF);
                   UPDATE config
                   SET lw_connection_type = connection_type,
                       lw_wan_http_port = wan_http_port,
                       lw_static_ip = static_ip,
                       lw_subnet_mask = subnet_mask,
                       lw_gateway = gateway,
                       lw_dns1 = dns1,
                       lw_dns2 = dns2
EOF
               }
           }
        }
    }
    $cfg = tools::get_config($dt,FRESH_READ);
    #printf "http_processor::config: fresh read %s\n" Dumper $cfg if DEBUG;
    $message .= $msg;
    printf "http_lan::errors:  %s\n", $message if (DEBUG && $message);
    $t->param( currcontype => $cfg->{connection_type});
    $t->param( wanport     => $cfg->{wan_http_port} );
    $t->param( currip      => $cfg->{static_ip});
    $t->param( currmask    => $cfg->{subnet_mask});
    $t->param( currgw      => $cfg->{gateway});
    $t->param( dns1    => $cfg->{dns1});
    $t->param( dns2    => $cfg->{dns2});
    $t->param( lanport  => $cfg->{lan_http_port});
    $t->param( dvruser  => $cfg->{dvr_user});
    $t->param( dvrpass  => $cfg->{dvr_password});
    $t->param( cameraip => $cfg->{camera_ip});
    $t->param( cameramask => $cfg->{camera_subnet_mask});
    system_load::get($t);

   #printf "http_processor::conf: html form  returned %s\n", Dumper $t;
   return ($t,"Update");
}

sub cameras
{
    my ($dt, $now, %form) = @_;
    my $t = HTML::Template->new_scalar_ref( html::cameras(),
            ( xdebug => 1, xstack_debug => 1 ) );
    my $filterSQL ="";
    my $cfg = tools::get_config($dt);
    if ($form{state} )
    {
        if ($form{state} =~ /^Delete\s*(\d*)/ )
        {
            my $camera_nbr = $1;
            delete_camera($dt,$camera_nbr);
            motion::create_motion_configs($dt);

        }
        elsif ($form{state} eq "Add")
        {
            my $name = $dt->trim($dt->trim($form{add_camera_name}));
            $name =~ tr/"',/---/;
            $dt->do("INSERT OR IGNORE INTO cameras (camera_name, server, channel, port) values(%s, 'Select Protocol', '1', 'default')", $name );
        }
        elsif ($form{state} eq "Update" )
        {
            # find all the camera_nbr fields, see html.pm for info
            my %records;
            foreach my $item (keys(%form))
            {
                my ($camera_nbr, $field) = split /\:/, $item;
                if ($field)
                {
                   $records{$camera_nbr} = "x";
                }
            }
            print "http_process:cameras\n",  Dumper(%records), "\n";
            foreach my $camera_nbr (keys %records)  # do each camera rowid
            {
                my $name = $dt->trim($form{$camera_nbr.":camera_name"});
                $name =~ tr/"',/---/;
				my $port = $form{$camera_nbr.":port"};
				#printf "port $name [%s]\n", $port;
				if (not($port eq 'default' or $port =~ /^[0-9]+$/))
				{
				    $port = "default";
				}
				
                my ($width, $height) = split "x", $form{$camera_nbr.":resolution"};
                $dt->do(<<EOF,
                UPDATE cameras
                SET camera_name = %s, wan_access = %s,
                ip_addr = %s, user = %s, password = %s, port = %s,  movie_output = %s, motion_area_detect = %s,
                rotate_image = %s, server = %s, width = %s, height = %s, channel = %s
                WHERE camera_nbr = %s
EOF
                   $name, $form{$camera_nbr.":wan_access"}||"",
                   $form{$camera_nbr.":ip_addr"},$form{$camera_nbr.":user"},$form{$camera_nbr.":password"},$port,
                   $form{$camera_nbr.":log_motion"}?'1':'0', $form{$camera_nbr.":motion_area_detect"},
                   $form{$camera_nbr.":rotate_image"}, $form{$camera_nbr.":server"}, $width, $height, $form{$camera_nbr.":channel"},
                   $camera_nbr);
            }
            motion::create_motion_configs($dt);
        }
    }
    # setup camera types AKA servers
    my $select_server = option_list_types($dt);
    my @cameras = $dt->tmpl_loop_query(<<EOF,
    SELECT cameras.camera_nbr, cameras.camera_name, cameras.server, cameras.port, cameras.wan_access, cameras.ip_addr, 
    cameras.user, cameras.password, 
    cameras.movie_output, cameras.motion_area_detect, cameras.rotate_image, coalesce(cameras.width,'640'),coalesce(cameras.height,'480'),
    camera_template.stream_url, cameras.channel
    FROM cameras
    LEFT JOIN camera_template ON camera_template.name = cameras.server 
    ORDER BY cameras.camera_name
EOF
   ( qw (camera_nbr camera_name server port wan_access ip_addr user password  movie_output motion_area_detect rotate_image width height url channel) ));
    my $ip_addr = ip_tools::get_ip_addr($cfg);
    $t->param( cameras => \@cameras );
    foreach my $x (@cameras)
    {
      if (exists $x->{movie_output} && $x->{movie_output} eq '1')
      {
          $x->{log_motion}='checked';
      }
      if (!$x->{rotate_image} || $x->{rotate_image} eq '0' || $x->{rotate_image} eq '180')
      {
         #$x->{rotate_image} = 0;
         $x->{portrait} = 0;
      }
      else #if ($x->{rotate_image} eq '90' || $x->{rotate_image} eq '270')
      {
         $x->{portrait} = 1;
      }
      $x->{url} =~ /^([a-z,A-Z]+):/;
      $x->{protocol} = $1;
      delete $x->{url};
      $x->{servers} = "<optgroup label='Current protocol'>\n".
                    "<option value ='".$x->{server}."' selected>".$x->{server}.'</option>\n'.
                    $select_server;
      delete $x->{server};
      delete $x->{movie_output};
      $x->{resolution} = $x->{width}.'x'.$x->{height};
      delete $x->{width};
      delete $x->{height};
    }
    $t->param( cameras => \@cameras );
    #print $dt->get_comments();
    return ($t,"Update");
}


sub set_timezone
{
    my ($dt, $now, %form) = @_;
    my $t = HTML::Template->new_scalar_ref( html::timezone(),
            ( xdebug => 1, xstack_debug => 1 ) );
    my $cfg = tools::get_config($dt,FRESH_READ);
    my $tz = $cfg->{timezone};
    if ($form{state} )
    {
        if ($form{state} eq "Set Timezone" )
        {
            $tz = $form{timezone};
            my $rc = $dt->do("UPDATE config SET timezone = %s", $tz);
            my $cmd = "sudo ".cfg::TIMEDATECTL." --no-ask-password --no-pager set-timezone  ".$tz."";
            printf("set_timezone %s\n", $cmd);
            #system(cfg::TIMEDATECTL,"--no-ask-password","set-timezone",$tz);
            my $trash = `$cmd`;
        }
    }
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

    $t->param( month =>  $abbr[$mon]);
    $t->param( day =>  sprintf("%02d",$mday));
    $t->param( year =>  $year + 1900);
    $t->param( hour =>  sprintf("%02d",$hour));
    $t->param( minute =>  sprintf("%02d",$min));
    $t->param( timezone =>  $tz);
    my @zones;
    my $get_zones = cfg::TIMEDATECTL." list-timezones";
    foreach my $zone (split "\n", `$get_zones`)
    {
         #print "[$zone]\n";
         my %rowdata;
         $rowdata{loc} = $zone;
         push(@zones, \%rowdata)
    }
    $t->param(zones =>  \@zones);
    return $t;
}

sub option_list_types
{
	my ($dt) = @_;
# setup camera types AKA servers
    my @servers;

	@servers = $dt->tmpl_loop_query(<<EOF, (qw(name desc)));
    select name from camera_template order by name
EOF
    
    my $select_server = '<optgroup label="Available protocols">\n'; 
    foreach my $s (@servers)
    {
		$select_server .= "<option value=".$s->{name}.'> '.$s->{name}.'</option>\n';  
	}
	return $select_server;
}

sub template
{
	my ($dt, $now, %form) = @_;
	printf "template: form = %s\n", Dumper \%form;
	my $t = HTML::Template->new_scalar_ref( html::template(),
            ( xdebug => 1, xstack_debug => 1 ) );
	$t->param(add_off_checked => 'checked');
	if (exists $form{state})
	{
		my ($name, $cmd) = split /\:/, $form{state};
		printf "name[%s] cmd[%s]\n",  $name, $cmd;
		my $safe_name = $dt->quote($name);
		
		if ($cmd eq "delete_template")
		{
            my ($rc, $del_url, $del_keepalive) = $dt->get_rec("select camera_template.stream_url, camera_template.netcam_keepalive
                    from camera_template
                    where camera_template.name = %s", $name);
            if ($rc)
            {
                
                $dt->do("delete from camera_template where name = %s", $name);  
                # place in add area
                $t->param(add_name => $name);
                $t->param(add_stream_url => $del_url);
                if ($del_keepalive eq "on")
                {
                    $t->param(add_on_checked =>  "checked");
                    $t->param(add_off_checked => "");
                }
                else
                {
                    $t->param(add_off_checked => "checked");
                    $t->param(add_on_checked =>  "");
                }
            }															
		}
		elsif ($cmd eq "update_url")
		{
			printf "replace this[%s] keepalive[%s]\n", $form{$name.':url'}, $form{$name.':keepalive'};
			$dt->do("insert or replace into camera_template (name, stream_url, netcam_keepalive) values (%s,%s,%s)",
			 $name, $form{$name.':url'}, $form{$name.':keepalive'} );
		}
		elsif ($cmd eq "add")
		{
			printf "add name[%s]\n\tstream[%s]\n\tsnapshot[%s] keepalive[%s]\n", $form{'add_camera_template_name'}, 
                    $form{'add_camera_template_stream_url'},$form{'add_keepalive'};
			
            my ($status) = $dt->do("insert into camera_template (name, stream_url, netcam_keepalive) values(%s,%s,%s)",
                 $form{'add_camera_template_name'}, $form{'add_camera_template_stream_url'}, $form{'add_keepalive'});
            if (!$status)
            {
                print("error could not add\n");
                $message = "Problem adding template, is it a duplicate?";

            } 
		}		
	}	
	
	my @template = $dt->tmpl_loop_query(<<EOF,
    SELECT camera_template.name,  camera_template.stream_url, camera_template.netcam_keepalive
    FROM camera_template
    ORDER BY camera_template.name
EOF
   ( qw (name url keepalive) ));
    
    my $last_tid = -1;
    foreach my $x (@template)
    {
		if ($x->{keepalive} eq "on")
		{
			$x->{on_checked} = "checked";
		}
		else
		{
			$x->{off_checked} = "checked";
		}		
		delete $x->{keepalive};	
		#if ($deleted_name_tid eq $x->{tid})
		#{
		#	$x->{deleted_name} = $deleted_name;
		#}
	}
    print("submitting template", @template);
	$t->param(templates => \@template);	
	return $t;
}

sub checked_value
{
    my ($text) = @_;
    return 'checked' if ($text =~ /checked/);
    return '';
}

sub check_ip_address
{
    my ($ip,$name) = @_;
    my $status;  # undef == good
    if (!$ip || $ip eq "")
    {
          # ok to be blank
    }
    else
    {
        if( $ip =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ )
        {
            if($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255)
            {
                # it is good;
            }
            else
            {
                $status = $name."[octets only 0>255 [".$ip."]]<br>";
            }
        }
        else
        {
           $status = $name."[Invalid format for IP [".$ip."]]<br>";
        }
    }
    return $status;
}

sub drop_index_html
{
    my ($where, $ip) = @_;
     my $t = HTML::Template->new_scalar_ref( html::index_html(),
            ( xdebug => 1, xstack_debug => 1 ) );
    $t->param(ip_addr => $ip);
    open FILE, ">$where/index.html";
    print FILE $t->output;
    close FILE;
}

sub delete_camera
{
   my ($dt, $nbr) = @_;
   printf "http_lan:main_page: removing %s\n", $nbr if DEBUG;
   $dt->do("DELETE FROM cameras WHERE camera_nbr = %s", $nbr);
   $dt->do("DELETE FROM motion_mask WHERE camera_nbr = %s", $nbr);
   $dt->do("DELETE FROM images WHERE camera_nbr = %s", $nbr);

}

1;
