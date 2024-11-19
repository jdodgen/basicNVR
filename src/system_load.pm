package system_load;
# copyright 2011 Jim Dodgen MIT Licence
#use HTML::Template;
use strict;

sub get
{
    my ($t) = @_;
    my $lscpu = `lscpu`;
    $lscpu =~ /CPU\(s\)\:.*([0-9]+)/;
    my $cores = $1;
    #print"cores = $1\n";
    my $uptime = `uptime`;
    $uptime =~ /load\s*average\:\s*([0-9]*\.?[0-9]+)\,\s*([0-9]*\.?[0-9]+)\,\s*([0-9]*\.?[0-9]+)/;
    my $min1 = int($1*100/$cores);
    my $min5 = int($2*100/$cores);
    my $min15 = int($3*100/$cores);
    if ($t)
    {
        $t->param( min1 => $min1);
        $t->param( min5 => $min5);
        $t->param( min15 => $min15);
    }
    else
    {
        print $uptime;
        printf("percent %s,%s,%s\n",$min1, $min5, $min15);
    }
}
#my $i = 0;
#while ($i < 10000000000)
#{
    #$i+=1;
#}
#get();

1;
