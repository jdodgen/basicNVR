package favicon;
require Convert::UU;
# Copyright 2020 by James E Dodgen Jr.  MIT Licence.
# use Convert::UU qw(uudecode);
sub get
{

my $icon = q~begin 0644 fav_icon
M```!``$`$!`0``$`!``H`0``%@```"@````0````(`````$`!```````@```
M````````````$```````````````_X0```@$````````````````````````
M```````````````````````````````````````````````````````````B
M(B(B(@```"$1$1$2````(1$1$1(````A$1$1$@``(B$1$1$2`"(2(1$1$1(B
M$1(A$1$1$A$1$B$1$1$2$1$2(1$1$1(B$1(A$1$1$@`B$B$1$1$2```B(1$1
M$1(````A$1$1$@```"(B(B(B``````````````#__P```#\````_````/P``
M`#P````P`````````````````````````#`````\````/P```#\````_``#_
#_P``
`
end~;

my $binary =  Convert::UU::uudecode $icon;
return $binary;
}

sub drop
{
    my ($where) = @_;
    my $icon = get();
    open FILE, ">$where/favicon.ico";
    print FILE $icon;
    close FILE;
}
1;
