# !/usr/bin/perl
my $pause;
if ($#ARGV == 0)
{
    $pause = 1;
}
use strict;

# to build the tar do this
# cd Dropbox/source/perl
# rm ../perl_modules.tar.gz
# tar -cvzf ../perl_modules.tar.gz  *


my @modules = split /\n/, <<EOF;
Try-Tiny
YAML-Tiny
File-Remove
Module-Install
Mozilla-CA
Digest-HMAC
Net-IP
Authen-SASL
Net-SSLeay

IO-Socket-SSL
libnet
Net-FTPSSL
Convert-UU
DBI
DBD-SQLite
LWP::UserAgent
Device-SerialPort
Device-XBee-API
File-ShareDir
HTML-Template
Locale-Msgfmt
Net-DNS
Net-HTTP
Net-SSH-Perl
Crypt-SSLeay
Net-SFTP
HTML-Parser
LWP-Protocol-https
libwww-perl
HTTP-Message
URI
HTTP-Date
LWP-MediaTypes
Filesys-Df
Crypt-Password
POSIX-RT-MQ
Math-Int64
CryptX
File-HomeDir
File-Which
Crypt-Curve25519
Path-Class
Crypt-Password
EOF

foreach my $m (@modules)
{
    printf "cleaning [%s]\n", $m;
    system ("cd $m*;make clean");
}

foreach my $m (@modules)
{
    printf "building [%s]\n>>", $m;
    <STDIN> if ($pause);
    system ("cd $m*;yes \"\" | perl Makefile.PL;yes \"\" | make;make install;cd ..");
}


foreach my $m (@modules)
{
    printf "cleaning [%s]\n", $m;

    system ("cd $m*;make clean");
}
