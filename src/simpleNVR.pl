# Copyright 2011-2020 by James E Dodgen Jr.  All rights reserved.
use Data::Dumper;
use IO::Socket;
use HTML::Template;
use html;
use DBI;
use Storable;
use DBTOOLS;
use strict;
use favicon;
use http_lan;
use motion;
use database;
use image_grabber;
use http_wan;
use cfg;
use watchdog;
#use ImpactVCB;
##use tools qw (:debug);
use constant DEBUG => 0;
use tools;


sub run_http_server
{
    $SIG{CHLD} = 'IGNORE';
    my $main_pid = getppid();
    my $config_at_start;
    {
        my $dt = database::open(cfg::DBNAME);
        $config_at_start = tools::get_config($dt);
    }
    my $ip  = ip_tools::get_ip_addr($config_at_start);
    my $lan_http_port = $config_at_start->{lan_http_port}||cfg::SERVICE_PORT;
    my $server = IO::Socket::INET->new(
        Proto     => 'tcp',
        LocalPort => $lan_http_port,
        Listen    => 4,
        ReuseAddr     => 1
    );
    if (! $server)
    {
      printf "simpleNVR LANserver: Unable to open LAN server port %s [$@]\n", $lan_http_port;
      sleep(20);
      return;
    }
    binmode $server;
    my $t;

    printf "simpleNVR:http_lan ip[%s] cfg port[%s]\n",$ip,$lan_http_port;
    my $last_request = 0;
    while ( my $client = $server->accept() )
    {
        my $now = time();
        #if ($now > $last_request+10) #eleminate double clicks
        {
            $last_request = $now;
            my $pid = fork;
            if ($pid)  # in parent
            {
                printf "simpleNVR: started ... >  %d\n", $pid if DEBUG;
                next;
            }
            die "fork failed: $!" unless defined $pid;
            my $menu_submit = process_request($client, $main_pid);
            print("done with process_request [$menu_submit]\n");
            if ($menu_submit eq 'restart')
            {
                system("killall motion");
                system("killall perl"); #that should do it!
            }
            exit 0;
        }
     }
}

sub process_request
{
    my ($client, $main_pid) = @_;
    my $dt = database::open(cfg::DBNAME);
    my $now = time;
    my $remote_IP = $client->peerhost();
    printf "simpleNVR:process_request:  recieved a request from  %s\n", $remote_IP if DEBUG;
    $client->autoflush(1);
    my $t;
    my $menu_submit;
    my $request;
    $client->recv($request,4096);
    if (defined $request )
    {
        #printf("process_request request [[[%s]]]\n", $request);
        my ($method, %form) = tools::parse_http_request($request);
        #print("method ",  $method, "\n");
        if (!$method) ## main page
        {
            $method="main";
        }
        if ($method eq "favicon.ico")
        {
            my ($icon) = favicon::get();
            $client->send("HTTP/1.0 200 OK\nContent-Type: image/x-icon\n\n".$icon);
            close $client;
            return "ok";
        }
        #elsif ($method eq 'list')
        #{
            #my $camera_name = $1;
              #$client->send("HTTP/1.0 200 OK\nContent-Type: text/plain\n\n".getListOfCameras($dt));
            #close $client;
            #return;
        #}
        #elsif ($method eq 'forceshapshots')
        #{
            #motion::forceSnapshots($dt);
            #$client->send("HTTP/1.0 200 OK\nContent-Type: text/plain\n\nrequested");
            #close $client;
            #return;
        #}
        elsif ($method =~ /^snapshot\/(.*)$/)
        {
            my $camera_name = $1;
            my ($status, $image) = image_grabber::get($dt, $camera_name,
                 {only_external =>  0, size => "small", return => "binary_image", nowait => 1});
            if ($image)
            {
              printf "simpleNVR:process_request:  sending image %s\n", $camera_name if DEBUG;
              $client->send("HTTP/1.0 200 OK\nContent-Type: image/jpeg\n\n".$image);
            }
            else
            {
              printf "simpleNVR:process_request:  no image found %s\n", $camera_name if DEBUG;
              $client->send("HTTP/1.0 404 OK\nContent-Type: text/html\n\nCould not get jpeg");
            }
            close $client;
            return "ok";
        }
        elsif ($method =~ /^path\/(.*)$/)
        {
            my $camera_name = $1;
            my ($status, $path) = image_grabber::get($dt, $camera_name,
                 {only_external =>  0, size => "small", return => "file_path", nowait => 1});
            if ($path)
            {
              printf "simpleNVR:process_request:  sending image %s\n", $camera_name  if DEBUG;
              $client->send("HTTP/1.0 200 OK\nContent-Type: text/plain\n\n".$path);
            }
            else
            {
              printf "simpleNVR:process_request:  no image found %s\n", $camera_name if DEBUG;
              $client->send("HTTP/1.0 404 OK\nContent-Type: text/html\n\nCould not get jpeg");
            }
            close $client;
            return "ok";
        }
        else
        {
            ($t, $menu_submit) = http_lan::process($method, $dt, $now, $main_pid, %form);
            if (! $t)
            {
                $client->send("HTTP/1.0 404 OK\nContent-Type: text/html\n\nunknown method");
                close $client;
                # print "end of routine", Dumper \%form;
                return "";
            }
        }

        # push out the form
        if ($t)
        {
          printf STDERR "submit = %s\n", $menu_submit if DEBUG;
          $t->param(form_action => html::form_action_LAN());
          my $m = HTML::Template->new_scalar_ref(html::menu());
          #$m->param(state => $menu_submit) if $menu_submit;
          $t->param(menu => $m->output);
          #tools::clean_html
          $client->send("HTTP/1.0 200 OK\nContent-Type: text/html\n\n".tools::clean_html($t->output));
        }
        else
        {
          $client->send("HTTP/1.0 200 OK\nContent-Type: text/html\n\nNothing to do?");
        }
        close $client;
    }
    return $menu_submit;
}

# run now
database::create_if_needed(cfg::DBNAME);
mkdir "/var/www/simplenvr/motion"; # make sure it exists
{
    my $dt = database::open(cfg::DBNAME);
    #get ethernet ports
    ip_tools::save_ports($dt);
    motion::create_motion_configs($dt);
    tools::create_htpasswd($dt);
    print "htpasswords created\n";
}

print "ownership changing \n";
system("chown -R www-data:www-data ".cfg::DBNAME);
system("chown -R www-data:www-data /database");
system('chown -R www-data:www-data /var/www/');
system("chown -R www-data:www-data /simplenvr");
system("chmod 777 /simplenvr/nvr.pl");

my $pid = fork;
if ($pid)  # in parent
{
    printf "simpleNVR: http::wan started ... >  %d\n", $pid; # if DEBUG;
}
else # IN FORKED CHILD
{
    die "fork failed: $!" unless defined $pid;
    http_wan::task();
    die "motion ended";
}
$pid = fork;
if ($pid)  # in parent
{
    printf "simpleNVR: watchdog started ... >  %d\n", $pid; # if DEBUG;
}
else # IN FORKED CHILD
{
    die "fork failed: $!" unless defined $pid;
    watchdog::task();
    die "watchdog ended";
}

run_http_server();
system("killall motion");
system("killall perl"); #that should do it!
