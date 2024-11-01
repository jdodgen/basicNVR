package image_grabber;
# Copyright 2011,2012 by James E Dodgen Jr.  MIT licence.
use Data::Dumper;
use strict;
#use IPcam;
use Carp;
use frownFace;

use constant DEBUG => 1;

# can return eather a binary jpg image or the path to a jpg file
#
sub get
{
    my ($dt, $camera_name, $options, $XbeeSendQueue) = @_;

    my $only_external = $options->{only_external};
    my $size          = $options->{size};
    my $nocache       = $options->{nocache}||0;
    my $after         = $options->{after}||0;  # if snapshot is not made after this epoch then wait for new one
    my $return = $options->{return};
    my $email_info;
    printf "image_grabber:get: requesting image [%s] as [%s]\n", $camera_name, $return if DEBUG;
    if (defined $options->{email_info})
    {
        $email_info = $options->{email_info};
    }
    my $query_tail="";
    if ($only_external && $only_external ==  1) # only get those allowed to be seen external http
    {
        $query_tail = qq( AND wan_access = "checked");
    }

    my ( $status, $camera_nbr, $server, $port, $ip_addr, $user, $password, $cfg_options ) = $dt->get_rec( <<EOF, $camera_name);
        SELECT camera_nbr, server, port, ip_addr, user, password, options FROM cameras WHERE camera_name = %s $query_tail
EOF
    if ( $status == 1 ) # found
    {

        my $jpeg_path = lastsnap_path($camera_nbr);
        my $is_jpg_yet = 0;
        if (-e $jpeg_path)
        {
            $is_jpg_yet = 1;
            while ($after > (stat $jpeg_path)[9]) # modification time
            {
                printf "image_grabber:get: waiting for fresh snapshot\n" if DEBUG;
                sleep(1);
            }
        }
        printf "image_grabber:get: image at %s\n", $jpeg_path if DEBUG;
        if ($return eq "binary_image")
        {
            if ($is_jpg_yet)
            {
                open(my $f, $jpeg_path) or warn "image_grabber:get: could not open image file $jpeg_path\n";
                undef $/;
                my $image = <$f>;
                close $f;
                return (1,$image);
            }
            else
            {
                return (1,frownFace::get());
            }
        }
        return (1,$jpeg_path);
    }
    return (0,frownFace::get());
}

sub lastsnap_path
{
    my ($camera_nbr) =@_;
    return cfg::SNAPSHOTS."$camera_nbr/lastsnap.jpg";
}

1;
# changes to use motion sw
# install ffmpeg and motion from source github jdodgen:motion

#
# https://www.linux.com/learn/tutorials/780055-how-to-operate-linux-spycams-with-motion
