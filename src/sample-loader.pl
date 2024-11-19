# !/usr/bin/perl
# Copyright 2011, 2012, 2013 by James E Dodgen Jr.  MIT Licence

use Net::SFTP::Foreign;
use IO::Zlib;
use Archive::Tar;
use strict;
use Data::Dumper;
my constant $retry_delay_time = 10;
my constant $run_dir      =  '/simplenvr';

# make these the same as cfg.pm
use constant FTP_SITE     => '????';
use constant FTP_USER     => '???';
use constant FTP_PASSWORD => '???';
use constant FTP_PORT     => 9005;

# my $ftp_site = $ftp_site1;
# $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $base_name = "simplenvr";
if (-d 'test')
{
    $base_name = 'test';
}
my $file_to_use;
my $local_file_name = getAndCheckLocalFile();  # look for a good local tar file
my $server_file_name;
my $loop_count=0;
my $remote_file_problem;
while (1)
{
  # we are looping until we get a good file from the server, or give up
  # if no local file then we loop untill we get a good file from the server
  if ($loop_count > 8 && $local_file_name)
  {
     $file_to_use = $local_file_name;
     last;
  }
  $remote_file_problem = 0;
  $loop_count++;

  my $ftps = connect_to_sftp("loader");
  #my $ftps = Net::SFTP->new($ftp_site,
                              #(user => $ftp_user,
                              #password => $ftp_password,
                              #Debug => 1));
  if (!$ftps)
  {
      printf "could not open the ftp connection = %s\n", FTP_SITE;
      #rotateFTPSite();
      sleep($retry_delay_time);
      next;
  }
  else
  {
      print "ftp open worked\n";
  }
  # now we are logged into the ftp server
  $server_file_name = getLatestServerFileName($ftps);

  printf "names found local = [%s] server = [%s]\n",
              $local_file_name||'No local file',
              $server_file_name||'Unable to get server file';

  if (!$server_file_name)  # looks like the server connection had a problem
  {
     if ($local_file_name)
     {
        $file_to_use = $local_file_name;
        last;
     }
     else
     {
         printf "no server file and no local file, only solution is to loop until we download a good one\n";
     }
  }
  else # a server file name was found
  {
     if ($local_file_name)
     {
        if (compareVersions($local_file_name, $server_file_name) == -1) # looks like there is a upgrade, so we go get it
        {
           my $result_server_file_name = getFileFromServer($ftps, $server_file_name);  # name is passed through if it is good, undef if it cannot be read
           if ($result_server_file_name)  # looks good,
           {
              $file_to_use = $server_file_name;
              last;
           }
           else
           {
              print "we found the server file name but ether we could not download it or it would not pass the tar test, so we are looping and setting a flag\n";
              $remote_file_problem = 1;
           }
        }
        else
        {
           printf "Local file [%s] is the same or newer (?) so we are using it\n", $local_file_name;
           $file_to_use = $local_file_name;
           last;
        }
     }
     else
     {
         printf "Server file found, no local file so we will just download and use the server file\n";
         $server_file_name = getFileFromServer($ftps, $server_file_name);  # name is passed through if it is good, undef if it cannot be read
         if ($server_file_name)  # looks good,
         {
            $file_to_use = $server_file_name;
            last;
         }
     }
  }
  ## $ftps->quit();
  printf "retrying after a %d second delay\n", $retry_delay_time;
  sleep($retry_delay_time);
}   # end of while(1)

# now time to clean up and unTar the executables

printf "local = [%s] server = [%s] using = [%s]\n",$local_file_name||"none found", $server_file_name||"none found", $file_to_use;
my $ver_number = sprintf "%d", getVersionNbr($file_to_use);
if (!defined $ver_number)
{
     print "patern match failed?\n";
     $ver_number=0;
}
if ($remote_file_problem == 1)
{
    my $server_version_number = sprintf "%d", getVersionNbr($server_file_name);
    $ver_number = "$ver_number problem $server_version_number";  # this causes the running application to avoid the fact that this server version had problems
}
system("rm -r  $run_dir");
mkdir $run_dir;

open VER, ">$run_dir/version.txt";
print VER $ver_number;
close VER;
# clean up old files
if ($file_to_use eq $local_file_name && $server_file_name && $local_file_name ne $server_file_name) # we picked the other one
{
    printf "removing [%s]\n",$server_file_name ;
    unlink $server_file_name;
}
elsif ($file_to_use eq $server_file_name && $local_file_name && $server_file_name ne $local_file_name) # we picked the other one
{
    printf "removing [%s]\n", $local_file_name;
    unlink $local_file_name;
}

my $tar_install = system('/bin/tar', ('-xvf', $file_to_use, '-C', $run_dir));
if ($tar_install == 0) # it worked
{
    system ('chown -R  www-data:www-data /simplenvr');
    print "programs extracted and ready to run\n";
}
else
{
    print "Unrecoverable error, could not extract programs from previous good tar file\n";
}
exit;




sub getLatestServerFileName
{
   my ($ftps) = @_;

   my $file_name;
   my $loop_count = 8; # try 8 times
   while ($loop_count--)
   {
     my $remote_files;
     eval {local $SIG{__DIE__}; $remote_files = $ftps->ls(".");};
     if ($@)
     {
        printf "die cause a fail in nlst [%s]\n", $@;
     }
     elsif (!$remote_files)
     {
         printf "Could not fetch remote file names [%s]\n", $ftps->status
     }
     else
     {
         my $last_seq = -1;
         foreach my $n (sort {compareSFTPVersions($a, $b)} @$remote_files)
         {
             ## chomp $n;
             if ($n->{filename} =~ /^$base_name(\d+)\.tar\.gz$/)
             {
                if ($1 > $last_seq)
                {
                  $last_seq = $1;
                  $file_name = $n->{filename};
                }
             }
         }
         printf "file name on server [%s]\n", $file_name;
         last;
     }
     sleep 2;
   }
   return $file_name;
}

sub getFileFromServer
{
  my ($ftps, $file_name) = @_;
  print "downloading file from server[$server_file_name] as [$file_name]\n";
  my $good_file_name;
  my $loop_count = 8;
  while($loop_count--)
  {
     my $stat = $ftps->get($server_file_name, $file_name);
     #printf "return is [%s][%s]\n", $stat, Dumper $stat;
     if ($stat)
     {
         print "/bin/tar -tf $server_file_name  >/dev/null 2>&1\n";

         my $tar_test = system("/bin/tar -tf $server_file_name  >/dev/null 2>&1");

         if ($tar_test == 0) # this one is good
         {
              printf "using downloaded file %s\n",$file_name;
              $good_file_name = $file_name;
         }
         else
         {
             print "testing $server_file_name with tar failed\n";
         }
         last;
     }
     else
     {
         printf "Problem getting remote file: %s [%s]", $file_name, $ftps->status;
         $file_to_use = $local_file_name;
         printf "Using local file %s\n", $local_file_name;
     }
  }
  return $good_file_name;
}

sub getAndCheckLocalFile
{
  my $file_name;
  if (!chdir "./pgm")
  {
    print "problem, could not find pgm directory\n";
  }
  print `pwd`;

  opendir(DIR,'.');
  my @curfiles = sort {compareVersions($a, $b)} readdir(DIR);
  closedir(DIR);
  printf "files found %s\n", $#curfiles;
  foreach my $n (@curfiles)
  {
     if ($n =~ /^$base_name(\d+)\.tar\.gz$/)
     {

        # looking for newest good one, should be only one
        my $tar_test = system("/bin/tar -tf $n >/dev/null 2>&1");
        if ($tar_test == 0) # this one is good
        {
            $file_name = $n;
            # printf "local file name [%s]\n", $local_file_name;
        }
     }
  }
  if ($file_name)
  {
      printf "latest good local file name [%s]\n", $file_name;
  }
  else
  {
      print "No good local files\n"; # must download
  }
  return $file_name;
}

sub getVersionNbr
{
  my ($in) = @_;
  my $nbr_out = $1 if ($in =~ /^$base_name(\d+)\.tar\.gz$/);
  return $nbr_out;
}

sub compareVersions
{
   my ($a, $b) = @_;
  my $a_num = getVersionNbr($a);
  my $b_num = getVersionNbr($b);
  return -1 if (defined $a_num && !defined $b_num);
  return  1  if (defined $b_num && !defined $a_num);
  return $a_num <=> $b_num if (defined $a_num);  ## note returns -1 if a is less than b
  return lc $a cmp lc $b;
}


sub compareSFTPVersions
{
   my ($a, $b) = @_;

  my $a_num = getVersionNbr($a->{filename});
  my $b_num = getVersionNbr($b->{filename});
  return -1 if (defined $a_num && !defined $b_num);
  return  1  if (defined $b_num && !defined $a_num);
  return $a_num <=> $b_num if (defined $a_num);  ## note returns -1 if a is less than b
  return lc $a->{filename} cmp lc $b->{filename};
}

sub connect_to_sftp
{
    my ($from_who) = @_;
    my $sftp;
    eval
    {
        $sftp = Net::SFTP::Foreign->new(FTP_SITE,
                        user => FTP_USER,
                        password => FTP_PASSWORD,
                        port => FTP_PORT,
                        more => [-o => 'StrictHostKeyChecking no']);
    };
    if ($@)
    {
       printf("sftp connect/new problem [%s] called by [%s]", $@, $from_who);
       #system "ssh-keygen -R ".FTP_SITE;
       return;
    }
    printf("using FTP site = %s\n", FTP_SITE);
    return $sftp;
}
