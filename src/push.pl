# !/usr/bin/perl
# Copyright 2011-2021 by James E Dodgen Jr.  All rights reserved.
# use IO::Zlib;


use strict;
use Data::Dumper;
use tools;

my $base = "simplenvr";
my $base_name = "simplenvr";

my $ftps = tools::connect_to_sftp("push");

if (!$ftps)
{
      print "could not open the ftp connection\n";
      exit -1;
}
#print "FTP connected, now logging in\n";

#if (!$ftps->login('alerta', 'R1kjed'))
#{
   #printf  "Could not login [%s]\n", $ftps->last_message();
   #exit -1;
#}

#if (!$ftps->binary())
#{
     #printf "Could not set binary [%s]\n", $ftps->last_message;
     #exit -1;
#}

#my @remote_files;
#@remote_files = $ftps->ls('.');
### print "ls returned ", Dumper \@remote_files, "/n";


#foreach my $n (sort {compareSFTPVersions($a, $b)} @remote_files)
#{

  #print $n->{filename}, "\n" if ($n->{filename} =~ /^simplenvr.*\.gz$/);
#}

my $remote_files = $ftps->ls('.');
## print "ls returned ", Dumper \@remote_files, "/n";


foreach my $n (sort {compareVersions($a, $b)} (@$remote_files))
{
  print $n->{filename}, "\n" if ($n->{filename} =~ /^simplenvr.*\.gz$/);
}

my $ver;
print "enter version number:";
$ver = <STDIN>;
chomp ($ver);
open FILE, '>', "version.pm";
print FILE "package version;\nuse constant VERSION => $ver;\n1;\n";
close FILE;

my $filename = sprintf "%s%d.tar.gz", $base, $ver;
printf "file name = %s\n", $filename;
my $del='Y';
if (-f $filename)
{
    print "tar file exists, delete?  (y,N) ";
    $del = <STDIN>;
}
if (uc($del) eq 'Y')
{
    unlink $filename;
    my $tar_test = system("tar -cvzf $filename --files-from files_to_tar");
    if ($tar_test != 0) # did not work
    {
               printf "tar failed\n";
               exit -1;
    }
}
  # now push it

print "press return to upload file\n>>>";
my $continue = <STDIN>;
if (!$ftps->put($filename, $filename))
{
     printf "send file result [%s]\n", $ftps->status;
     exit -1;
}
print "finished ok\n";

sub getVersionNbr
{
  my ($in) = @_;
  my $nbr_out = $1 if ($in =~ /^$base_name(\d+)\.tar\.gz$/);
  return $nbr_out;
}

sub compareVersions
{
   my ($a, $b) = @_;

  my $a_num = getVersionNbr($a->{filename});
  my $b_num = getVersionNbr($b->{filename});
  return -1 if (defined $a_num && !defined $b_num);
  return  1  if (defined $b_num && !defined $a_num);
  return $a_num <=> $b_num if (defined $a_num);  ## note returns -1 if a is less than b
  return lc $a->{filename} cmp lc $b->{filename};
}

