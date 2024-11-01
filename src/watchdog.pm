package watchdog;
use Filesys::Df;
use Fcntl qw(:flock);
use cfg;
use strict;

my $timeToSleep = 60*5;  # 5 minutes
my $amount_to_clean = 20000000; # 20 meg
my $last_free = localtime;

#task();
sub task
{
	print "Starting Watchdog\n";
	
	while (1)
	{
		checkDiskSpace();
		sleep $timeToSleep;
	}
}

sub checkDiskSpace
{         
	my $Cleaned = CheckAndFreeDiskSpace(cfg::MOTION_DIR, $amount_to_clean);	
	if ($Cleaned > 0)
	{
		$last_free = localtime;
		rebuildImageTable();
		return 1;
	}
	printf "Watchdog: was cleaned? %s, last clean: %s\n", $Cleaned ? "YES":'NO', $last_free;
    return 0;
}

#sub cmper
#{
    ###my ($a,$b) = @_;
    ##print "$a $b ";
    #$a =~ '^/motion/.*?/(.*$)';
    #my $aa = $1;
    #$b =~ '^/motion/.*?/(.*$)';
    #my $bb = $1;
    ##print "$aa cmp $bb\n";
    ##sleep(1);
    #return $aa cmp $1;
#}

sub CheckAndFreeDiskSpace
{
    my ($path, $amount_to_clean) = @_;
    my $cleaning = 0;
    my $bignumber = '99999';
	open my $file, ">", cfg::FREEDISKSPACELOCK or die $!; 
	if (flock $file, LOCK_EX|LOCK_NB)
	{ # we have the lock	
		
		while (1)	# keep removing a month at a time untill free enough		
		{
			my $used_percent = df('/')->{per};
			printf "used percent [%s] clean chunk [%s]\n", $used_percent,  $amount_to_clean;
			last if ($used_percent < 99);  # we clean when 99 percent full
			 
			my $find_string = 'find '.cfg::MOTION_DIR.' -maxdepth 3';			
			my @direcories = split '\n', `$find_string`;
			#print @direcories;
			my $oldest_yr = $bignumber;
			my $oldest_mo = $bignumber;
			foreach my $d (@direcories) # find oldest year/month
			{
				print "$d\n";
				my ($trash,$camstuff) = split 'motion/', $d;
				print "$camstuff\n";	
				my ($cam,$year,$month) = split '/', $camstuff;							
				print "year $year oldest $oldest_yr\n";
				print "month $month oldest $oldest_mo\n";
				if (defined $month and defined $year)
				{
					 if ($year le $oldest_yr) # now check months
					 {
						if ($year lt $oldest_yr) # first time we found a lessor year
						{ 
							$oldest_yr = $year;
							$oldest_mo = $bignumber; # reset month check (bug fix Jan 2023)
						}							
						if ($month lt $oldest_mo)
						{									
							$oldest_mo = $month;
						}	
					}
				}			
			}
			print "removing oldest year month  $oldest_yr - $oldest_mo\n";
			last if $oldest_yr eq $bignumber;
			$cleaning++;
			my $remove_pattern = cfg::MOTION_DIR.'/*/'.$oldest_yr.'/'.$oldest_mo;
			print $remove_pattern."\n";
			system "rm -r $remove_pattern";
		}
		# now wanting to clean empty years and empty cameras
		#
		cleanCameraTree() if ($cleaning); 
	}
	else
	{
		print "locked out [$!]\n";
	}
	close $file;
	#print "exiting\n";
    return $cleaning;
}

sub cleanCameraTree
{
	my $find_string = 'find '.cfg::MOTION_DIR.' -maxdepth 2';			
	my @direcories = split '\n', `$find_string`;
	foreach my $d (reverse @direcories) # find all cameras and years
	{
		print "checking for empty [$d]\n";
		if (is_directory_empty($d) and $d ne cfg::MOTION_DIR)
		{
			rmdir($d);
			print "deleted [$d]\n";
		}
	}	
}

sub is_directory_empty 
{ 
	my $dirname = shift; 
	opendir(my $dh, $dirname) or die "Not a directory"; 
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0; 
}

sub rebuildImageTable
{
    return;   # ignore while testing see if conflicts
    open my $file, ">", cfg::REBUILDIMAGETABLELOCK or die $!; 
	if (flock $file, LOCK_EX|LOCK_NB)
	{
		my $pid = fork;
		if ($pid)  # in parent
		{
		  printf "processManager:startSingle: forked ...pid = %s \n", $pid;
		  return;
		}
		die "fork failed: $!" unless defined $pid;
		setpriority(0,$$,5);

		my $dt = db::open(cfg::DBNAME,1); # this is a open with out autocommit on
		print "motion:rebuildImageTable  starting ...\n";
		$dt->do("DELETE FROM images");
		$dt->commit;
		print "rebuilding image table\n";
		my $m = cfg::MOTION_DIR;
		opendir FN, $m;
		my @camera_nbrs = readdir FN;
		closedir FN;
		my $commit_count = 0;
		foreach my $camera_number (@camera_nbrs)
		{
			next if (!(-d $m.$camera_number) || $camera_number eq '..' ||  $camera_number eq '.');
			opendir FN, $m.$camera_number;
			my @years = readdir FN;
			closedir FN;
			foreach my $year (@years)
			{

				next if (!(-d $m.$camera_number."/".$year) || $year eq '..' ||  $year eq '.');
				#print "$camera_number $year\n";
				opendir FN, $m.$camera_number."/".$year;
				my @months = readdir FN;
				closedir FN;
				# $dt->begin;
				foreach my $month (@months)
				{
					#print "$month\n";
					next if (!(-d $m.$camera_number."/".$year."/".$month) || $month eq '..' ||  $month eq '.');
					opendir FN, $m.$camera_number."/".$year."/".$month;
					my @days = readdir FN;
					closedir FN;
					foreach my $day (@days)
					{
						next if (!(-d $m.$camera_number."/".$year."/".$month."/".$day) || $day eq '..' ||  $day eq '.');
						opendir FN, $m.$camera_number."/".$year."/".$month."/".$day;
						my @hours = readdir FN;
						closedir FN;
						foreach my $hour (@hours)
						{
							next if (!(-d $m.$camera_number."/".$year."/".$month."/".$day."/".$hour) || $hour eq '..' ||  $hour eq '.');
							opendir FN, $m.$camera_number."/".$year."/".$month."/".$day."/".$hour;
							my @minutes = readdir FN;
							closedir FN;
							foreach my $minute (@minutes)
							{
								next if (!(-d $m.$camera_number."/".$year."/".$month."/".$day."/".$hour."/".$minute) || $minute eq '..' ||  $minute eq '.');
								opendir FN, $m.$camera_number."/".$year."/".$month."/".$day."/".$hour."/".$minute;
								my @videos = readdir FN;
								closedir FN;
								foreach my $video (@videos)
								{
									if ($video =~ /\.mp4$/)
									{
										my $video_file_name = $m.$camera_number."/".$year."/".$month."/".$day."/".$hour."/".$minute.'/'.$video;
										#print "$video_file_name\n";
										$dt->do("insert or ignore into images (camera_nbr, file_name, year, month, day, hour, minute) ".
											   "values ($camera_number,%s, %s,%s,%s,%s,%s)",
											   $video_file_name,$year,$month,$day,$hour,$minute);
										$commit_count++;
										if ($commit_count > 100)
										{
											$commit_count = 0;
											$dt->commit;
										}

									}
								}
							}
						}
						$dt->commit; # also commit for each day
					}
				}
			}
		}
		$dt->commit; # then at the end,
		print "motion:rebuildImageTable  finished\n";
	}
	close $file;
}
