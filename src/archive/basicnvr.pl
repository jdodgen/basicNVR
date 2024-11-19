# 
#!/usr/bin/perl -w
use strict;
use warnings;

# open(my $fh, '<', 'home');
# my $ip = <$fh>;
# close $fh;
# chomp $ip;
# my ($addr, $port) = split(":", $ip);
my $addr = "192.168.0.2";
print "Content-Type: text/html\n\n".<<EOF;
<HTML>
<HEAD>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=windows-1252">
<TITLE>BasicNVR</TITLE>
<style type="text/css">
      html, body, #map-canvas { height: 100%; margin: 0; padding: 0;}
</style>
</HEAD>
<BODY TEXT="#000000" LINK="#0000ff" VLINK="#000080"  BACKGROUND=/snowman.jpg ALINK="#FF0000" onload="initialize()">

  <!-- BGCOLOR="#ffffff" -->
<!-- <font face="Comic Sans MS"> -->
<p style="font-size:80px">
EOF
printf "<a href=\"https://%s/nvr\">BasicNVR login</a><br><br>\n",  $addr;


print <<EOF;
</p>
</body>
</HTML>
EOF
exit;