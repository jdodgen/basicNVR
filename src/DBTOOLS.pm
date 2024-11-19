package DBTOOLS;
# Copyright 2011,2017,2024 by James E Dodgen Jr.  MIT Licence.
use strict;

require Exporter;
our ( @ISA, @EXPORT_OK, %EXPORT_TAGS );
use Carp qw(cluck);

# dbi wrapper for use with HTML::Template
# property of Jim Dodgen
#

sub new
{
  my $pkg = shift;
  my $self; { my %hash; $self = bless(\%hash, $pkg); }

  for (my $x = 0; $x <= $#_; $x += 2)
  {
    defined($_[($x + 1)]) or croak("DBTOOLS::new() called with odd number of option parameters - should be of the form option => value");
    $self->{lc($_[$x])} = $_[($x + 1)];
    # print "loading hash lc($_[$x]) = $_[($x + 1)]\n";
  }
  #print "new called \n";
  return $self;
}


sub get_comments
{
   my ($self) = @_;
   # print "XXXX ".$self->{login_comments};
   if (exists $self->{login_comments})
   {
     return "DBTOOLS::get_comments\n".$self->{login_comments}."DBTOOLS_END\n";
   }
   return "DBTOOLS::get_comments none\n";
}

sub put_comments
{
   my ($self, $string) = @_;

   $self->{login_comments}.=$string."\n" if (exists($self->{trace}));
}

sub get_rec_hashref
{
   my ($self, $rsql, @parms) = @_;
   chomp $rsql;
   $rsql=$self->trim($rsql);
   my $sql;
   if (@parms)
   {
      for (my $i = 0; $i <= $#parms; $i++)
      {
        # $self->{login_comments} .= "[$i]\n" if (exists($self->{trace}));
        $parms[$i] = $self->{dbh}->quote($parms[$i]);
        $self->{login_comments} .= "parm=".$parms[$i]."\n" if (exists($self->{trace}));
      }
      $sql = sprintf($rsql, @parms);
   }
   else
   {
      $sql = $rsql;
   }
   $self->{login_comments} .= "get_rec_hashref [$sql]\n" if (exists($self->{trace}));
   # print "$sql\n";
   ###   my $sth = $dbh->prepare("SELECT * FROM mytable");
   my $results = $self->{dbh}->selectrow_hashref($sql);

   # cluck if (!@results);
   $self->{login_comments}.="get_rec_hashref selectrow_array col returned [$sql]\n" if (exists($self->{trace}));
   if (!$results && defined($self->{dbh}->err))   # this is an sql error
   {
      $self->{login_comments} .= "get_rec_hashref selectrow_array failed".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return 0, \{error => $self->{dbh}->errstr};
   }
   elsif (!$results) # this is nothing returned from query
   {
      $self->{login_comments} .= "get_rec_hashref returned zero records\n" if (exists($self->{trace}));
      return 0, \{error =>  "nothing found"};
   }
   # print "[$self->{login_comments}]\n";
   return 1, $results;
}

sub last_insert_rowid
{
    my ($self) = @_;
    return $self->{dbh}->sqlite_last_insert_rowid();
}

sub rows_changed
{
    my ($self) = @_;
    return $self->{rows} eq '0E0'?0:$self->{rows};
}

sub get_rec
{
   my ($self, $rsql, @parms) = @_;
   chomp $rsql;
   $rsql=$self->trim($rsql);
   my $sql;
   if (@parms)
   {
      for (my $i = 0; $i <= $#parms; $i++)
      {
        # $self->{login_comments} .= "[$i]\n" if (exists($self->{trace}));
        $parms[$i] = $self->{dbh}->quote($parms[$i]);
        $self->{login_comments} .= "parm=".$parms[$i]."\n" if (exists($self->{trace}));
      }
      $sql = sprintf($rsql, @parms);
   }
   else
   {
      $sql = $rsql;
   }
   $self->{login_comments} .= "get_rec [$sql]\n" if (exists($self->{trace}));
   ## print "$sql\n";
   ###   my $sth = $dbh->prepare("SELECT * FROM mytable");
   my @results = $self->{dbh}->selectrow_array($sql);
   # cluck if (!@results);
   $self->{login_comments}.="get_rec selectrow_array col returned = $#results [$sql]\n" if (exists($self->{trace}));
   if ($#results == 0 && defined($self->{dbh}->err))   # this is an sql error
   {
      $self->{login_comments} .= "get_rec selectrow_array failed $results[0]".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return (0, $self->{dbh}->errstr);
   }
   elsif ($#results < 0) # this is nothing returned from query
   {
      $self->{login_comments} .= "get_rec returned zero records\n" if (exists($self->{trace}));
      return (0, "nothing found");
   }
   # print "[$self->{login_comments}]\n";
   return (1, @results);
}

sub do_a_block
{
    my ($self, $block) = @_;
    $block =~ tr/\n/ /;
    my $errors=0;
    my @lines = split ";", $block;
    foreach my $line (@lines)
    {
       $errors += $self->do($line);
    }
}

sub begin
{
    my ($self) = @_;
    $self->{dbh}->begin_work;
}

sub commit
{
    my ($self) = @_;
    $self->{dbh}->commit;
}

sub do
{
   my ($self, $rsql, @parms) = @_;
   chomp $rsql;
   $rsql=$self->trim($rsql);
   my $sql;
   if (@parms)
   {
      for (my $i = 0; $i <= $#parms; $i++)
      {
        if(!defined $parms[$i] or $parms[$i] eq "")
        {
           $parms[$i]="NULL";
        }
        else
        {
          $parms[$i] = $self->{dbh}->quote($parms[$i]);
          $self->{login_comments} .= "parm=".$parms[$i]."\n" if (exists($self->{trace}));
        }
      }
      #  all the nulls are ro make sure we cover all trailing %s in the printf string
      #$sql = sprintf($rsql, (@parms, ("NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL")));
      $sql = sprintf($rsql,@parms);
   }
   else
   {
      $sql = $rsql;
   }

   #print "do [".$sql."]\n";
   $self->{login_comments} .= "do [".$sql."]\n" if (exists($self->{trace}));
   for (my $i = 0; $i < 10; $i++)
   {
      my $stat = $self->{dbh}->do($sql);
      $self->{rows} = $stat;
      #printf "DBTOOLS::do returned from do[%s]\n", $stat;
      if (!$stat)
      {
         if ($self->{dbh}->err == 5) # locked
         {
             sleep(1);  # just a little wait for it to unlock
         }
         else
         {
            cluck "DBTOOLS do failed\n$sql\nUnable execute ".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n";
            return 0;
         }
      }
      else
      {
        return 1;
      }
   }
   return 0;
}

sub query_to_hash
{
    # retreves a single row into a hash keyed by column id
    my ($self, $rsql, @parms) = @_;
    chomp $rsql;
    $rsql=$self->trim($rsql);
    my $sql;
    if (@parms)
   {
      for (my $i = 0; $i <= $#parms; $i++)
      {
        if(!exists $parms[$i])
        {
           $parms[$i]="NULL";
        }
        else
        {
          $parms[$i] = $self->{dbh}->quote($parms[$i]);
          $self->{login_comments} .= "parm=".$parms[$i]."\n" if (exists($self->{trace}));
        }
      }
      #  all the nulls are ro make sure we cover all trailing %s in the printf string
      $sql = sprintf($rsql,@parms);
      #$sql = sprintf($rsql, (@parms, ("NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL")));
   }
   else
   {
      $sql = $rsql;
   }
    $self->{login_comments} .= "query_to_hash [$sql]\n" if (exists($self->{trace}));
    my $sth = $self->{dbh}->prepare($sql);
    if (!defined($sth))
    {
      $self->{login_comments} .= "query_to_hash Unable to prepare [$sql] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      $self->{login_comments}  .= "query_to_hash Unable execute [$sql] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my %hash;
    while( my ($l,$v) = $sth->fetchrow_array )
    {
       $hash{$l} = $v;
    }
    $sth->finish;
    return \%hash;
}

sub query_prepare
{
    my ($self, $search) = @_;
    chomp $search;
    $search=$self->trim($search);
    my $sth = $self->{dbh}->prepare($search);
    if (!defined($sth))
    {
      $self->{login_comments} .= "query_prepare: Unable to prepare [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    return $sth;
}

sub loop_query_execute
{
    my ($self, $sth, @labels) = @_;
    my @lov;

    if (!defined($sth))
    {
      $self->{login_comments} .= "loop_query_execute bad prepared staatement handle"  if (exists($self->{trace}));
      return;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      ##print "loop_query_execute Unable execute ".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n";

      $self->{login_comments}  .= "loop_query_execute Unable execute ".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }

    while( my @row = $sth->fetchrow_array )
    {
       ##print "loop_query_execute processing a row\n";
       my %fld_set;
       foreach my $lbl (@labels)
       {
           $fld_set{$lbl}= shift @row;
       }
       push (@lov, \%fld_set);
    }

    return @lov;
}

sub get_rec_hashref_execute
{
    my ($self, $sth) = @_;


    if (!defined($sth))
    {
      $self->{login_comments} .= "get_rec_hashref_execute bad prepared staatement handle"  if (exists($self->{trace}));
      return 0;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      ##print "get_rec_hashref_execute Unable execute ".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n";

      $self->{login_comments}  .= "get_rec_hashref_execute Unable execute ".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $results = $sth->fetchrow_hashref;
    return (1,$results);
}


sub query_finish
{
    my ($self, $sth) = @_;
    $sth->finish;
}

sub tmpl_loop_query
{
    my ($self, $search, @labels) = @_;
    chomp $search;
    $search=$self->trim($search);
    my @lov;
    $self->{login_comments} .= "tmpl_loop_query [$search]\n" if (exists($self->{trace}));
    my $sth = $self->{dbh}->prepare($search);
    if (!$sth)
    {
      print print "DBTOOLS $search\n";
      $self->{login_comments} .= "tmpl_loop_query Unable to prepare [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      $self->{login_comments}  .= "tmpl_loop_query Unable execute [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }

    while( my @row = $sth->fetchrow_array )
    {
       my %fld_set;
       foreach my $lbl (@labels)
       {
           $fld_set{$lbl}= shift @row;
       }
       push (@lov, \%fld_set);
    }
    $sth->finish;
    return @lov;
}

sub query_hash_of_hash
{
    # first field will be the main hash key, the rest of the fields will be the internal hash
    my ($self, $search, @labels) = @_;
    chomp $search;
    $search=$self->trim($search);

    $self->{login_comments} .= "tmpl_loop_query [$search]\n" if (exists($self->{trace}));
    my $sth = $self->{dbh}->prepare($search);
    if (!defined($sth))
    {
      $self->{login_comments} .= "tmpl_loop_query Unable to prepare [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      $self->{login_comments}  .= "tmpl_loop_query Unable execute [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my %hash;
    while( my @row = $sth->fetchrow_array )
    {
       my $hash_key = shift @row;
       my %fld_set;
       foreach my $lbl (@labels)
       {
           $fld_set{$lbl} = shift @row;
       }
       $hash{$hash_key} = \%fld_set;
    }
    $sth->finish;
    return \%hash;
}


sub query_row_per_hash
{
    # this query returns a single hash with each returned record a hash entry
    # the hash name is the first field the hash value is the second field
    # any other fields are ignored
    my ($self, $search) = @_;
    chomp $search;
    $search=$self->trim($search);
    my @lov;
    $self->{login_comments} .= "tmpl_loop_query [$search]\n" if (exists($self->{trace}));
    my $sth = $self->{dbh}->prepare($search);
    if (!defined($sth))
    {
      $self->{login_comments} .= "tmpl_loop_query Unable to prepare [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      $self->{login_comments}  .= "tmpl_loop_query Unable execute [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my %hash;
    while( my @row = $sth->fetchrow_array )
    {
        $hash{$row[0]}= $row[1];
    }
    $sth->finish;
    return %hash;
}

sub query_to_array_of_hash
{
    # name is table name, first returned field is hash key, the rest go in by name list
    my ($self, $search) = @_;
    chomp $search;
    $search=$self->trim($search);

    $self->{login_comments} .= "query_to_array_of_hash [$search]\n" if (exists($self->{trace}));
    my $sth = $self->{dbh}->prepare($search);
    if (!defined($sth))
    {
      $self->{login_comments} .= "query_to_array_of_hash Unable to prepare [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      $self->{login_comments}  .= "query_to array_of_hash Unable execute [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return;
    }
    my $tbl_ary_ref = $sth->fetchall_arrayref({});
    $sth->finish;
    return $tbl_ary_ref;
}


sub query_to_array
{
    # name is table name
    my ($self, $search, $skip, $limit) = @_;
    chomp $search;
    $search=$self->trim($search);
    if (!defined($limit))
    {
        $limit=100;
    }
    my @csv_lines=();
    $self->{login_comments} .= "query_to_array [$search]\n" if (exists($self->{trace}));
    my $sth = $self->{dbh}->prepare($search);
    if (!defined($sth))
    {
      $self->{login_comments} .= "query_to_array Unable to prepare [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      return (-1, ($self->{dbh}->err,$self->{dbh}->errstr));
    }
    my $stat = $sth->execute;
    if (!defined($stat))
    {
      $self->{login_comments}  .= "query_to_array Unable execute [$search] SELECT:".$self->{dbh}->err.", ".$self->{dbh}->errstr."\n" if (exists($self->{trace}));
      $sth->finish;
      return (-1, ($self->{dbh}->err,$self->{dbh}->errstr));
    }
    while( my @row = $sth->fetchrow_array)
    {
        push(@csv_lines, \@row); # array of arrays
        $limit--;
        if ($limit < 1)
        {
            last;
        }
    }
    $sth->finish;
    return (1, @csv_lines);
}


sub quote
{
   my ($self, $thing) = @_;
   return $self->{dbh}->quote($thing);
}

sub trim {
    my ($self, $string) = @_;
    if (!defined($string))
    {
      return "";
    }
    $string  =~  s/^\s+//;
    $string  =~  s/\s+$//;
    if ($string eq "")
    {
        return "";
    }
    return $string;
}

sub trim_quote {
    my ($self, $string) = @_;
    if (!defined($string))
    {
      return "null";
    }
    $string  =~  s/^\s+//;
    $string  =~  s/\s+$//;
    if ($string eq "")
    {
        return "null";
    }
    return $self->{dbh}->quote($string);
}

# print "passed through package\n";
1;
