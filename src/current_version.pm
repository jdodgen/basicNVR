package current_version;
use cfg;
use tools;
use Data::Dumper;
use strict;
 
sub get
{
    my $ftps = tools::connect_to_sftp("current_version");
    
    #my $ftps = Net::SFTP->new(cfg::FTP_SITE,
                            #(user => cfg::FTP_USER,
                            #password => cfg::FTP_PASSWORD,
                            #xxssh_args => [options => ['StrictHostKeyChecking=no']],
                            #warn => 'true',
                            #debug => 0));
    #printf "using FTP site [%s]\n", cfg::FTP_SITE;
    if (!$ftps)
    {
        printf "could not open the ftp connection\n";
        return 0;
    }
    else
    {
      #print "ftp open worked\n";
    }
    # now we are logged into the ftp server
    return getLatestServerVersionNumber($ftps);
}

sub getLatestServerVersionNumber
{
    my ($ftps) = @_;

    my $remote_files = $ftps->ls('.', wanted => qr/simple/);
    if (!$remote_files)
    {
        printf "Could not fetch remote file names [%s]\n", $ftps->status
    }
    else
    {
        my $largest = 0;
        my $basename = cfg::BASENAME;
        foreach my $r (@$remote_files)
        {
            if ($r->{filename} =~ /^simple/)
            {
                $r->{filename} =~ /^$basename(\d+)\.tar\.gz$/;
                #print $1."\n";
                $largest = $1 if ($1 > $largest);
            }
        }
        return $largest;
    }
    return 0;
}
##print get();
1;
