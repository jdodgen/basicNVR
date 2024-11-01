package ip_tools;
# Copyright 2011,2012 by James E Dodgen Jr.  All rights reserved.

# use Net::DNS;
use Net::Ping;
use tools;
use strict;

my  $ifconfig = "/sbin/ifconfig"; #used for getting the IP address
my $last_ip_read_time = 1;
my $last_ip;
sub get_ip_addr
{
    my ($cfg, $WorkerBeeQueue) = @_;
    #lock $last_ip_read_time;
    my $now = time;
    if ($now > $last_ip_read_time + 3600 || !$last_ip)  # Only check every hour
    {
       my $interface = $cfg->{ethernet_port};
       my @lines     = qx|$ifconfig $interface|
         or die( "Can't get info from ifconfig: " . $! );
       $last_ip = undef;
       foreach (@lines)
       {
           if (/inet\s(addr:)*([\d.]+)/)
           {
               $last_ip = $2;
               # print "new ";
               $last_ip_read_time = $now;
               last;
           }
       }
   }
   if ($last_ip)
   {
      # print "get_ip_addr = $last_ip\n";
   }
   elsif ($WorkerBeeQueue)
   {
      $WorkerBeeQueue->enqueue({request => "LOG", fmt => "no IP adress found, probable DHCP fail, no connection?"});
      $last_ip = 'NO.IP.ADDRESS.found';
   }
   if (wantarray)
   {
     return split /\./, $last_ip;
   }
   return $last_ip;
}

sub set_ip
{
    my ($dt) = @_;

    my $rc = 0;

    my $cfg = tools::get_config($dt);
    if ($cfg->{connection_type} eq 'DHCP') # this works all the time, so just get out
    {
        set_ip_dhcp($cfg->{ethernet_port},
                    $cfg->{camera_ethernet_port}, $cfg->{camera_ip}, $cfg->{camera_subnet_mask});
        $rc = 0;
    }
    else # lets see if the primary one works
    {
        set_ip_static($cfg->{ethernet_port},$cfg->{static_ip},$cfg->{subnet_mask},
                     $cfg->{gateway},  $cfg->{dns1}, $cfg->{dns2},
                     $cfg->{camera_ethernet_port}, $cfg->{camera_ip}, $cfg->{camera_subnet_mask});
        if (check_network_health() == 0) # did not work
        {
             if ($cfg->{lw_connection_type} eq 'DHCP') # this works all the time, so just get out
             {
                set_ip_dhcp($cfg->{ethernet_port});
                $rc = 1;
             }
             else # lets try the secondary (AKA last working lw_ )
             {
               set_ip_static($cfg->{ethernet_port},$cfg->{lw_static_ip},$cfg->{lw_subnet_mask},
                             $cfg->{lw_gateway},  $cfg->{lw_dns1}, $cfg->{lw_dns2});
               if (check_network_health() == 0) # did not work again
               {
                   set_ip_dhcp($cfg->{ethernet_port});
                   $rc = 2;
               }
               else
               {
                   $rc = 1;
               }
             }

         }
         else # primary worked
         {
            $rc = 0;
         }
    }
    $last_ip_read_time=0;
    if ($cfg->{camera_ip} && $cfg->{camera_ip} > '' && $cfg->{camera_ethernet_port} && $cfg->{camera_ethernet_port} > "")
    {
        my $camaraNet = "ip addr add ".$cfg->{camera_ip}."/24 dev ".$cfg->{camera_ethernet_port};
        system($camaraNet);
    }

    return $rc; # 0 = primary worked, 1 = backup worked, 2 = both failed reverted to DHCP
}

sub set_ip_dhcp
{
  my ($port, $camport, $camip, $cammask) = @_;
  my $interfaces_file1 = <<EOF;
# configured from basicNVR DHCP
#
network:
 ethernets:
  $port:
   dhcp4: yes
EOF

  drop_netplan($interfaces_file1.camera_network($camport, $camip, $cammask));
}

##sudo ip addr add 192.168.2.2/24 dev enp1s0

##sudo ip link set dev enp1s0 up



sub save_ports
{
    my ($dt) = @_;
    my @result = split "\n", `netstat -r | grep "^default"`;
    my ($default, @other) = @result;
    #print "ip_tools::save_port: netstat line [$default]\n";
    chomp $default;
    $default =~ /.+\s(.*)$/;
    my $port = $1;
    print "ip_tools::save_ports: primary port = [$port]\n";

    my $all_ports = `ip a | grep '^[1-9]\:'`;
    #print "\n$all_ports\n";
    my $extraPort;
    foreach my $line (split "\n", $all_ports)
    {
        #print("line == [$line]\n");
        if ($line =~ /^[1-9]\:\s*(.*?)\:/)
        {
            my $p = $1;
            #print"found [$1]\n";
            $extraPort=$p if ($p ne "lo" && $p ne $port);
        }
    }
    print "ip_tools::save_ports: camera port = [$extraPort]\n";
    $dt->do("update config set ethernet_port = %s, camera_ethernet_port = %s", $port, $extraPort) if $dt;
}

#save_ports();


sub set_ip_static
{
    my ($port, $ip, $mask, $gw, $dns1, $dns2, $camport, $camip, $cammask) = @_;
    my $cider = mask_to_cidr($mask);
    
    my $dns_string1 ='';
    my $dns_string2 ='';
    if ($dns1 && $dns2)
    {
        $dns_string1 = "nameservers:";
        $dns_string2 = "addresses: [$dns1, $dns2]";
    }
    elsif ($dns1)
    {
        $dns_string1 = "nameservers:";
        $$dns_string2 = "addresses: [$dns1]";
    }
    elsif ($dns2)
    {
        $dns_string1 = "nameservers:";
        $dns_string2 = "addresses: [$dns2]";
    }
  my $interfaces_file = <<EOF;
# configured from basicNVR static IP
#
network:
 version: 2
 ethernets:
  $port:
    dhcp4: no
    addresses: [$ip/$cider]
    gateway4: $gw
    optional: true
    $dns_string1
      $dns_string2
EOF

  drop_netplan($interfaces_file.camera_network($camport, $camip, $cammask));
}

sub camera_network # are we setting up a camera only network
{
	my ($camport, $camip, $cammask) = @_;	
	if ($camip) 
	{
		my $cider = mask_to_cidr($cammask);
		my $cam_stuff = <<EOF;
# Camera network
#

  $camport:
    dhcp4: no
    addresses: [$camip/$cider]
EOF
	
		return $cam_stuff;
	}
	return '';
}	
	

sub drop_netplan
{
  my($interfaces_file) = @_;
  my $yaml = "/etc/netplan/01-net.yaml";
  system('sudo rm  /etc/netplan/*.yaml');
  system("sudo touch $yaml");
  system("sudo chmod 666 $yaml");
  open FILE, '>'.$yaml or die "cannot open $yaml for writing: $!";
  print FILE $interfaces_file;
  close FILE;
  system('sudo /usr/sbin/netplan apply');
}

sub check_network_health
{
    system ($ifconfig);
    return 1;

    my $host = 'gmail.com';
    my $rc = 0;
    for (my $i=0;$i < 10; $i++)
    {
        my $p = Net::Ping->new();
        if ($p->ping($host))
        {
            print "$host is alive.\n";
            $rc = 1;
            last;
        }
        $p->close();
        sleep 1;
    }
    return $rc;
}

sub mask_to_cidr
{
    my($mask) = @_;
    my($byte1, $byte2, $byte3, $byte4) = split(/\./,$mask);
    my $num = ($byte1 * 16777216) + ($byte2 * 65536) + ($byte3 * 256) + $byte4;
    my $bin = unpack("B*", pack("N", $num));
    return ($bin =~ tr/1/1/);
}

#printf "port = %s\n", get_port();
#printf "port = %s\n", get_port();

# printf "ip=%s\n", scalar get_ip_addr();

1;
