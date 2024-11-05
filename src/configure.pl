# !/usr/bin/perl
use strict;
my $yn;
print "auto run all steps (Yn)?";
my $runall = <STDIN>;
get_packages();
setup_apache();
fix_bashrc();
fix_sudoers();
#enlarge_msg_queues();
fix_swappiness();
make_directories();
#build_ffmpeg();
build_motion();
build_pm();
edit_mingetty();

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

sub get_packages
{

    print "apt-get packages(Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);
    print "doing updates and upgrades\n";
    system ('yes \'\' | apt-get update');
    system ('yes \'\' | apt-get upgrade');
    system ('yes \'\' | apt-get dist-upgrade');

    print "installing packages for motion\n";

    system ('yes \'\' | apt-get install autoconf autopoint automake pkgconf libtool   libjpeg8-dev  build-essential  libzip-dev');
    system ('yes \'\' | apt-get install libmicrohttpd-dev ffmpeg libavformat-dev  libavcodec-dev   libavutil-dev   libswscale-dev transcode');  ##  libav-tools
    system ('yes \'\' | apt-get install libavdevice-dev libsqlite3-dev');

    print "remove cloud-init\n";
    system ('yes \'\' | apt-get purge cloud-init');
    system ('rm -rf /etc/cloud/');
    system ('rm -rf /var/lib/cloud/');

    print "installing other packages\n";
    system ('yes \'\' | apt-get install pkg-config gcc zlib1g-dev mingetty libssl-dev make libz-dev yasm sqlite3');
    system ('yes \'\' | apt-get install apache2 software-properties-common unzip autoconf python python-pip');
    system ('yes \'\' | apt install livemedia-utils net-tools preload network-manager');
    system ('yes \'\' | pip install requests');
    system ('apt-get remove brltty');
    system ('apt-get autoremov');

    print "packages loaded\n";

}

sub setup_apache
{
    print "apache ssl setup(Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);
    system "chsh -s /bin/bash www-data";
    system 'a2enmod ssl';
    mkdir '/etc/apache2/ssl';
    chdir '/etc/apache2/ssl';
    print "genrsa just enter foobar for passphrase\n";
    system 'openssl genrsa -des3 -out server.key  -passout pass:foobar 1024';
    print "now generating insecure\n";
    system 'openssl rsa -in server.key -out server.key.insecure -passin pass:foobar';
    print "now generating csr\n";
    system "openssl req -new -key server.key.insecure -out server.csr -subj '/C=US/ST=Califonia/L=LA/CN=simplenvr/emailAddress=jim\@dodgen.us'";
    print "openssl x509 this should be run ever so often to keep '-days' fresh\n";
    system 'openssl x509 -req -days 1000 -in server.csr -signkey server.key.insecure -out server.crt';
    system 'a2ensite default-ssl';
    system 'a2enmod cgid';
    system 'a2enmod rewrite';
    replace_default_ssl(); ## replace default-ssl.conf with ours
    replace_default_http(); ## replace http.conf with ours
    mkdir '/var/www/simplenvr';
    chmod 0755, '/var/www/simplenvr';
    mkdir "/var/www/simplenvr/motion";
    mkdir "/database";
    system ("ln -s /simplenvr/nvr.pl /var/www/simplenvr/nvr");
    system ("ln -s /simplenvr/favicon.ico /var/www/simplenvr/favicon.ico");
    system ("ln -s /dev/shm/snapshots /var/www/simplenvr/snapshots");
    system ('chown -R www-data:www-data /database');
    system ('chown -R www-data:www-data /var/www');
    system 'service apache2 restart';
    chdir '/root';

}

sub fix_sudoers
{
    print "fix_sudoers (Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);
    my $tail = <<EOF;
www-data ALL=(ALL) NOPASSWD:ALL
EOF
     open(PLOT,">>/etc/sudoers") || die("sudoers file will not open!");
     print PLOT $tail;
     close(PLOT);
     print "sudoers modified\n";
}

sub fix_bashrc
{
    print "fix_bashrc (Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);

     my $tail = <<EOF;
echo
echo '********************************************'
echo 'this is the basicNVR start up'
echo 'Copyright 2021, 2024 Jim Dodgen MIT Licence'
echo 'control C to interupt now'
umask 0000
preload
setterm -blank 0
ulimit -q 536870912
sleep 20
/usr/bin/perl /root/loader.pl
cd /simplenvr
runuser -l www-data -c "/usr/bin/perl -I /simplenvr /simplenvr/basicNVR.pl"
echo rebooting now control C to stop reboot
sleep 20
reboot
EOF
     open(PLOT,">>.bashrc") || die(".bashrc file will not open!");
     print PLOT $tail;
     close(PLOT);
     print "bashrc modified\n";
}

sub fix_swappiness
{
    print "fix_swappiness (Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);
    {
        my $tail = <<EOF;
vm.swappiness=10
EOF

        open(PLOT,">>/etc/sysctl.conf") || die(".bashrc file will not open!");
        print PLOT $tail;
        close(PLOT);

        print "bashrc modified\n";
   }
}

sub make_directories
{
    mkdir "/root/pgm";
    mkdir "/root/perl";
}

sub build_pm
{
    print "Make perl modules (Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);

    my @modules = split /\n/, <<EOF;
CPAN
inc::latest
Try::Tiny
YAML
YAML::Tiny
File::Remove
Mozilla::CA
Digest::HMAC
Net::IP
Authen::SASL
Net::SSLeay
IO::Socket::SSL
IO::Pty
libnet
Convert::UU
DBI
DBD::SQLite
Net::HTTP
libwww::perl
HTTP::Date
HTTP::Message
HTML::Parser
LWP::UserAgent
Device::SerialPort
File::ShareDir
HTML::Template
Locale::Msgfmt
Net::DNS
Net::OpenSSH
Net::SFTP::Foreign
LWP::Protocol::https
URI
LWP::MediaTypes
Filesys::Df
Crypt::Password
Math::Int64
CryptX
File::HomeDir
File::Which
Crypt::Curve25519
Path::Class
Crypt::Password
Astro::Sunrise
POSIX::RT::MQ
Text::CSV
EOF

# Net::FTPSSL, Net::SSH::Perl, Net::SFTP  not used anymore

    foreach my $m (@modules)
    {
        printf "\n>>>>installing [%s]<<<<<\n\n", $m;
        system ("yes '' | cpan install $m");
    }
}

#sub build_pm
#{
    #print "Make perl modules (Yn)? ";
    #$yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    #return if ($yn =~ /n/);

    #chdir '/root/perl';
    #system 'tar -xvf ../perl_modules.tar.gz';
    #system 'perl pm_build.pl';
    #chdir '/root';
#}
sub build_ffmpeg
{
    print "Make ffmpeg(Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);

    system 'tar -xvf ffmpeg.tar.gz';
    chdir 'ffmpeg';
    system './configure;make;make install';
    chdir '/root';
}

sub build_motion
{
    print "Make Motion(Yn(? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);

    chdir '/root';
    system 'unzip motion-master.zip';
    chdir 'motion-master';
    system 'autoreconf -fiv';
    system './configure --with-sqlite3';
    #system q(sed -i '/^LIBS\s/ s/$/ -lswresample/' Makefile);
    system 'make;make install';
    chdir '/root';

}

sub edit_mingetty
{
    # my $systemd = q(sed -i '/^ExecStart/ c\ExecStart=-/sbin/mingetty --autologin root tty1' /etc/systemd/system/getty.target.wants/getty@tty1.service);
    print "edit_mingetty (Yn)? ";
    $yn = ($runall =~ /n/) ? <STDIN> : 'Y';
    return if ($yn =~ /n/);
    if (-d '/etc/systemd/system/getty.target.wants')  # using systemd
    {
        my $systemd = <<EOF;
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
EOF

        mkdir '/etc/systemd/system/getty@tty1.service.d';
        open(TTY,q(>/etc/systemd/system/getty@tty1.service.d/autologin.conf)) || die("autologin.conf file will not open/create!");
        print TTY $systemd;
        close(TTY);
    }
    elsif (-d '/etc/init')  # pre 15 ubuntu
    {
        system 'vi /etc/init/tty1.conf'; # (ubuntu)
    }
    else
    {
        system 'vi /etc/inittab'; #  (debian)
    }
}

sub replace_default_ssl
{
    my $ssl =
'<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin jim@dodgen.us
        ServerName simplenvr

        DocumentRoot /var/www/simplenvr
        AddType video/mp4 .mp4
        AddType video/ogg .ogv
        AddType video/webm .webm
        ErrorLog /database/error.log
        CustomLog /database/access.log combined

        #Include conf-available/serve-cgi-bin.conf

        SSLEngine on
        SSLCertificateFile  /etc/apache2/ssl/server.crt
        SSLCertificateKeyFile /etc/apache2/ssl/server.key.insecure


        #SSLOptions +FakeBasicAuth +ExportCertData +StrictRequire
        # ScriptAlias /cgi-bin/ /var/www/simplenvr/
        # AddHandler cgi-script cgi
        <FilesMatch "^[^\.]+$">
                SSLOptions +StdEnvVars
                SetHandler cgi-script
        </FilesMatch>

        <Directory "/var/www/simplenvr/">
            AllowOverride none
            AuthName "simpleNVR Home Access"
            AuthUserFile "/database/htpasswd"
            AuthType Basic
            Require valid-user
            Options +ExecCGI -Multiviews +FollowSymLinks
            Order allow,deny
            Allow from all
        </Directory>
    </VirtualHost>
</IfModule>
';
    open(SSL, '>', '/etc/apache2/sites-available/default-ssl.conf') || die("default-ssl.conf file will not replace!");
    print SSL $ssl;
    close(SSL);
}

sub replace_default_http
{
    my $http =
 '<VirtualHost *:80>
        ServerAdmin jim@dodgen.us
        DocumentRoot /var/www/html

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        ScriptAlias /cgi-bin/ /var/www/html/
        AddHandler cgi-script cgi
        <FilesMatch "^[^\.]+$">
                SetHandler cgi-script
        </FilesMatch>

        <Directory "/var/www/html/">
            AllowOverride All
            RewriteEngine on
            RewriteCond %{HTTPS} !on
            RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}
            Options +ExecCGI -Multiviews +SymLinksIfOwnerMatch
            Order allow,deny
            Allow from all
        </Directory>
</VirtualHost>
';
    open(HTTP, '>', '/etc/apache2/sites-available/000-default.conf') || die("000-default.conf file will not replace!");
    print HTTP $http;
    close(HTTP);
}


