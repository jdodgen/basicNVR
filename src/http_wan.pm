package http_wan;
# Copyright 2011-2024 by James E Dodgen Jr.  MIT Licence.
use Data::Dumper;
use IO::Socket;
use IO::Socket::SSL;
use strict;
use HTML::Template;
use html;
use image_grabber;
use database;
use ip_tools;
use POSIX ":sys_wait_h";
use tools;
use cfg;
use constant DEBUG => 1;
use constant FRESH_READ => 1;

#my $db_name;
my $ip;
sub task
{
    setpriority(0,$$, 2);
    $SIG{CHLD} = 'IGNORE';
    my ($trace_in) = @_;
    $! = 1;
    my $dt = database::open(cfg::DBNAME);
    my $cfg  = tools::get_config($dt, FRESH_READ);
    my $web_server;
    {
        my $trys=0;
        while ($trys < 2)
        {

            $ip = ip_tools::get_ip_addr($cfg);

            printf "http_wan ip[%s] cfg port[%s]\n", $ip, $cfg->{wan_http_port};
            my $wan_server_port = $cfg->{wan_http_port}||cfg::EXTERNAL_PORT;
            $web_server = IO::Socket::INET->new(
                Proto     => 'tcp',
                LocalPort => $wan_server_port,
                Listen    => SOMAXCONN,
                ReuseAddr => 1);
            if ($web_server)
            {
                $trys=1000;
                printf "http_wan accepting WAN clients at http://%s:%s]\n",$ip,$wan_server_port;
            }
            else
            {
                $trys++;
                printf "http_wan Unable to open WAN server %s:%s ,sleeping and retrying", $ip, $wan_server_port;
                sleep(10);
            }
        }
    }
    if (! $web_server) # problem with opening webserver port, should reboot just to check things out if the reboot fails then need to set to port 9000
    {
       print "WAN server defaulting to 9000";
       $web_server = IO::Socket::INET->new(
         Proto     => 'tcp',
         LocalPort => cfg::DEFAULT_SERVER_PORT,
         Listen    => SOMAXCONN,
         ReuseAddr => 1);
       if (! $web_server)
       {
         print "Unable to open default WAN server port 9000";
         sleep(20);
         return;
       }
       printf "http_wan:task: accepting clients on DEFAULT port http://%s:%s]\n", $ip, cfg::DEFAULT_SERVER_PORT;
    }

    binmode $web_server;

    # my $local_ip = tools::get_ip_addr(); # this is use to allow access to cameras when internal
    while ( my $client = $web_server->accept() )
    {
      my $pid = fork;
      if ($pid)  # in parent
      {
         printf "http_wan:task: started ... >  %d\n", $pid;
         next;
      }
      die "fork failed: $!" unless defined $pid;
      ## SSL upgrade client (in new process/thread)
      #IO::Socket::SSL->start_SSL($client,
        #SSL_server => 1,
        #SSL_cert_file => 'cert.pem',
        #SSL_key_file => 'key.pem',
      #) or die "failed to ssl handshake: $SSL_ERROR";
      process_request($client);
      exit 0;
     }
}


sub process_request
{
    my ($client) = @_;

    my $remote_IP = $client->peerhost() ;
    if ($remote_IP)
    {
        printf "http_wan:process_request: recieved a request from  %s\n", $remote_IP if DEBUG;
    }
    binmode $client;
    my $request;
    $client->recv($request,1024);
    if (defined $request )
    {
        my ($method, %form) = tools::parse_http_request($request);
        if (!$method)
        {
            printf "http_wan:process_request:  method=[%s]\n", "No method"  if DEBUG;
        }
        else
        {
            my $printable = $request;
            $printable =~ s/.*[^[:print:]]+//;
            printf "http_wan:process_request:  method=[%s] request=[%s]\n", $method, $printable  if DEBUG;
        }

      # printf "DVRserver:process_request:  method: %s\n", $method||"Nothing passed in"  if DEBUG;
    if (!$method)
    {
        print $client "HTTP/1.0 200 OK\nContent-Type: text/html\n\n";
        print $client "<h2>basicNVR external server, Nothing requested</h2>\n";
    }
    elsif ($method eq "favicon.ico")
    {
        print $client "HTTP/1.0 200 OK\nContent-Type: text/html\n\n";
        print $client "User-agent: *\nDisallow: /\n";
    }
    elsif ($method =~ /^robots.txt/)
    {
        print $client "HTTP/1.0 200 OK\nContent-Type: text/html\n\n";
        print $client "User-agent: *\nDisallow: /\n";
    }
    else
    {
    # the following need a database connection
        my $dt = database::open(cfg::DBNAME);
        my ($is_trusted, $trusted_ip) = $dt->get_rec("select ip from trusted_ip where ip = %s",$remote_IP); #returns 1 if found
        if (!$method)
        {
          report_unauthorized_access($dt, $client, $remote_IP);
        }
        elsif ($method =~ /^camera/)
        {
            my ($func, $location, $nocache) = split /\//, $method;
            my $nc = 0;
            if ($nocache && $nocache eq "nocache")
            {
                $nc = 1;
            }

            #my $only_external = ($status) ? 0:1;  # we allow the trusted IP to see ALL pictures

            my ($stat,$image) = image_grabber::get($dt, $location,{nocache => $nc, only_external =>  (1 - $is_trusted), size => "std", return => "binary_image"});

            if (! $image) # not found
            {
                my $t = HTML::Template->new_scalar_ref(html::simple_list(),
                        ( xdebug => 1, xstack_debug => 1 ) );
                $t->param(desc => "Camera [$location] not found<br>Accessable Cameras are:");
                my @cameras = $dt->tmpl_loop_query("select camera_name, \"/cameras/\"||camera_name from cameras where wan_access = \"checked\"",(qw (item link)) );
                $t->param( items => \@cameras);
                $client->send("HTTP/1.1 200 OK\nContent-Type: text/html\n\n".tools::clean_html($t->output));
            }
            else
            {
                $client->send("HTTP/1.1 200 OK\nContent-Type: image/jpeg\n\n".$image);
            }
        }
        elsif ($method =~ /^list/)
        {
            if ($is_trusted)
            {
                my $list='';
                my ($s,@cameras) = $dt->query_to_array("SELECT camera_name from cameras");
                foreach my $c (@cameras)
                {
                    $list .= $c->[0].",";
                }
                chop $list;
                print  "[$list]\n";
                $client->send("HTTP/1.1 200 OK\nContent-Type: text/html\n\n".$list);
            }
            else
            {
                $client->send("HTTP/1.1 200 OK\nContent-Type: text/html\n\n"."nothing");
            }
        }
        #elsif ($method =~ /^raw/)
        #{
            #my ($func, $location, $nocache) = split /\//, $method;
            #my $nc = 0;
            #if ($nocache && $nocache eq "nocache")
            #{
                #$nc = 1;
            #}
            #my $only_external = ($remote_IP eq $trusted_ip) ? 0:1;  # we allow the trusted IP to see ALL pictures

            #my ($stat,$image) = image_grabber::get($dt, $location,{nocache => $nc, only_external =>  $only_external, size => "std", return => "binary_image"});
            #$client->send($image);
        #}
        else #unknow method, might  be a hack in progress
        {
            #report_unauthorized_access($dt, $client, $remote_IP);
        }
      }
    }
  close $client;
}
sub report_unauthorized_access
{
    my ($dt, $client, $remote_IP) = @_;
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
    print $client "HTTP/1.0 200 OK\nContent-Type: text/html\n\n";
    print $client "Unathorised access attempt: logged and reported: 18 U.S.C. &sect; 1030(a)(1)\n";
}

1;
