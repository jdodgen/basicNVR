($byte1, $byte2, $byte3, $byte4) = split(/\./, "255.255.255.0");
$num = ($byte1 * 16777216) + ($byte2 * 65536) + ($byte3 * 256) + $byte4;
$bin = unpack("B*", pack("N", $num));
$count = ($bin =~ tr/1/1/);
print "$bin = $count bits\n";
