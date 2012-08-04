#! /usr/bin/perl -w

use strict;
use Getopt::Std;

my %args;

getopts ('v', \%args);

# CHECKING THE BALLOT FILE
my $filename = shift or die ("Error: missing argument.\nUsage: $0 [-v] FILENAME\n");
open (my $fh, "<", $filename) or die ("Error: opening argument file: $!");


print "Verbose mode activated.\n\n" if $args{v};

#
# ACQUIRING DATA FROM THE FILE (pairs creation)
#
my %aliases;
my %pairs;
my %ids2num;
foreach (<$fh>)
{
  next if ($_ =~ m/^\s+$/); # blank line
  if ($_ =~ m/^\s*(?:\d+\s*:)?\s*[^>=\s]+(?:\s*[>=]\s*[^>=\s]+)*\s+$/) # ballot line
  {
    my $times;
    if ($_ =~ m/^\s*(\d+)\s*:/)
    {
      $times = $1;
    }
    else
    {
      $times = 1;
    }
    my ($v) = ($_ =~ m/^(?:\d+\s*:)?\s*([^>=\s]+(?:\s*[>=]\s*[^>=\s]+)*)\s+$/);
    my @parts_of_vote = split(/\s*\b\s*/, $v);
    my $alternator = 1;
    my @viewed;
    my @not_viewed = grep { $_ !~ m/^[>=]$/ } @parts_of_vote;
    foreach (@not_viewed)
    {
      $ids2num{$_} = scalar (keys %ids2num) if (not exists $ids2num{$_});
    }
    foreach (@parts_of_vote)
    {
      if (($_ eq ">" or $_ eq "=") and $alternator == 0)
      {
	$alternator = 1;
	if ($_ eq ">")
	{
	  foreach my $sup (@viewed)
	  {
	    foreach my $inf (@not_viewed)
	    {
	      $pairs{"$ids2num{$sup}/$ids2num{$inf}"} += $times;
	    }
	  }
	  @viewed = ();
	}
      }
      else
      {
	if ($alternator == 1)
	{
	  $alternator = 0;
	  push (@viewed, $_);
	  if ($_ ne shift (@not_viewed))
	  {
	    print "COHERENCE ERROR 1\n";
	    exit 3;
	  }
	}
	else # error
	{
	  print "PARSE ERROR: line $.: confusion between identificators and ";
	  print "operators.\n";
	  exit 2;
	}
      }
    }
  }
  else
  {
    if ($_ =~ m/^\s*#\s*([^:\s]+)\s*:=\s*(.+)\n$/) # alias line
    {
      $aliases{$1} = $2;
      print "\"\033[01m$1\033[0m\" is aliased by \"\033[01m$2\033[0m\"\n"
	if ($args{v});
    }
    else # error
    {
      print "PARSE ERROR: line $.:\n$_ is neither a ballot nor an alias.\n";
      exit 2;
    }
  }
}
print "\n" if ($args{v} and scalar (keys %aliases) > 0);

my @ids = keys %ids2num;
my %num2ids = reverse %ids2num;
undef %ids2num;
foreach (keys %num2ids)
{
  $num2ids{$_} = $aliases{$num2ids{$_}} if (exists $aliases{$num2ids{$_}});
}


#
# PAIR CONFRONTATION & SIMPLIFICATION
#

my %margin;
for (my $i = 0; $i < scalar @ids; $i++)
{
  for (my $j = $i + 1; $j < scalar @ids; $j++)
  {
    if (exists $pairs{"$i/$j"} and exists $pairs{"$j/$i"})
    {
      if ($pairs{"$i/$j"} >= $pairs{"$j/$i"})
      {
	$margin{"$i/$j"} = $pairs{"$i/$j"} - $pairs{"$j/$i"};
	delete $pairs{"$i/$j"} if ($margin{"$i/$j"} == 0);
	delete $pairs{"$j/$i"};
      }
      else
      {
	$margin{"$j/$i"} = $pairs{"$j/$i"} - $pairs{"$i/$j"};
	delete $pairs{"$j/$i"} if ($margin{"$j/$i"} == 0);
	delete $pairs{"$i/$j"};
      }
    }
    else
    {
      $margin{"$i/$j"} = $pairs{"$i/$j"} if (exists $pairs{"$i/$j"});
      $margin{"$j/$i"} = $pairs{"$j/$i"} if (exists $pairs{"$j/$i"});
    }
  }
}

#
# DEFEATS SORTING
#

my @defeats_serial = sort { $pairs{$b} <=> $pairs{$a}
  or $margin{$b} <=> $margin{$a} } keys %pairs;

my @defeats;
my @stock;
my $i = 0;
foreach (@defeats_serial)
{
  if (scalar @stock > 0)
  {
    if ($pairs{$_} == $pairs{$stock[0]} and $margin{$_} == $margin{$stock[0]})
    {
      push (@stock, $_);
    }
    else
    {
      my @equals = @stock;
      $defeats[$i++] = \@equals;
      @stock = ($_);
    }
  }
  else
  {
    push (@stock, $_);
  }
}
if (scalar @stock > 0)
{
  $defeats[$i] = \@stock;
}

if ($args{v})
{
  print "\033[01mStudied pairs:\033[0m\n";
  my $i = 1;
  foreach (@defeats)
  {
    foreach (@{$_})
    {
      my ($a, $b) = ($_ =~ m%^(\d+)/(\d+)$%);
      print "  $i. \033[04m$num2ids{$a}\033[0m defeats ";
      print "\033[04m$num2ids{$b}\033[0m (strength: $pairs{$_}; ";
      print "margin: $margin{$_})\n";
    }
    $i++;
  }
  print "\n";
}


#
# GRAPH CONSTRUCTION
#

my %graph;
foreach (@defeats)
{
  my %forbidden_edges = creates_cycle ($_);
  foreach my $pair (@{$_})
  {
    next if (exists $forbidden_edges{$pair});
    my ($win, $loose) = ($pair =~ m%^(\d+)/(\d+)$%);
    if (exists $graph{$win})
    {
      push (@{$graph{$win}}, $loose);
    }
    else
    {
      $graph{$win} = [ $loose ];
    }
  }
}

# return a hash containing the edges that create cycles in the graph
sub creates_cycle
{
  my @edges = @{$_[0]};
  my (@winners, @loosers);
  my %pseudograph = %graph;
  foreach (keys %pseudograph)
  {
    my @t = @{$graph{$_}};
    $pseudograph{$_} = \@t;
  }
  foreach (@edges)
  {
    my ($win, $loose) = ($_ =~ m%^(\d+)/(\d+)$%);
    push (@winners, $win);
    push (@loosers, $loose);
    if (exists $pseudograph{$win})
    {
      push (@{$pseudograph{$win}}, $loose);
    }
    else
    {
      $pseudograph{$win} = [ $loose ];
    }
  }
  my @scc_set = tarjan_scc_finder (%pseudograph);
  my %removed_edges;
  foreach my $edge (@edges)
  {
    my ($win, $loose) = ($edge =~ m%^(\d+)/(\d+)$%);
    foreach (@scc_set)
    {
      if (scalar (grep { $_ == $win or $_ == $loose } @{$_}) == 2)
      {
	$removed_edges{$edge} = 1;
	last;
      }
    }
  }
  return %removed_edges;
}

sub vertices_set
{
  my $g = $_[0];
  my %set;
  foreach (keys %$g)
  {
    $set{$_} = 1;
    $set{$_} = 1 foreach (@{$g->{$_}});
  }
  return keys %set;
}

# Given a graph, returns its strongly connected components.
sub tarjan_scc_finder
{
  my %graph = @_;
  my @vertices = vertices_set (\%graph);
  my %v_index;
  my %v_lowlink;
  my $index = 0;
  my @stack = ();
  my @partition = ();

  sub min
  {
    my @t = sort { $a <=> $b } @_;
    return $t[0];
  }

  sub is_in
  {
    my ($elt, @t) = @_;
    my %h = map { $_ => 1 } @t;
    return (exists $h{$elt});
  }

  sub tarjan_strongconnect
  {
    my ($v, $graph, $v_index, $v_lowlink, $stack, $index, $partition) = @_;

    $v_index->{$v} = $$index;
    $v_lowlink->{$v} = $$index;
    $$index += 1;
    push (@$stack, $v);
    if (exists $graph->{$v})
    {
      foreach my $w (@{$graph->{$v}})
      {
	if (not exists $v_index->{$w})
	{
	  tarjan_strongconnect ($w, $graph, $v_index, $v_lowlink,
	      $stack, $index, $partition);
	  $v_lowlink->{$v} = min ($v_lowlink->{$v}, $v_lowlink->{$w});
	}
	else
	{
	  $v_lowlink->{$v} = min ($v_lowlink->{$v}, $v_index->{$w})
	  if (is_in ($w, @$stack));
	}
      }
    }
    if ($v_lowlink->{$v} == $v_index->{$v}) # $v is a root node
    {
      my ($w, @scc) = (-1);
      while ($w != $v)
      {
	$w = pop (@$stack);
	push (@scc, $w);
      }
      # if the strongly connected component contains more than one vertex
      # => cycle found
      push (@$partition, \@scc) if (scalar @scc > 1);
    }
  }

  foreach my $v (@vertices)
  {
    next if (exists $v_index{$v});
    tarjan_strongconnect ($v, \%graph, \%v_index, \%v_lowlink,
      \@stack, \$index, \@partition);
  }
  return @partition;
}

if ($args{v})
{
  print "\033[01mDefeat graph:\033[0m\n";
  foreach (keys %graph)
  {
    print "  \033[04m$num2ids{$_}\033[0m defeats:\n";
    print "    $num2ids{$_}\n" foreach (@{$graph{$_}});
  }
  print "\n";
}


#
# INVERSE GRAPH COMPUTATION
#

my %rgraph;
foreach my $vrtx (keys %graph)
{
  foreach (@{$graph{$vrtx}})
  {
    if (exists $rgraph{$_})
    {
      push (@{$rgraph{$_}}, $vrtx);
    }
    else
    {
      $rgraph{$_} = [ $vrtx ];
    }
  }
}

#
# FINAL LISTING
#

my @final_scores;
my @remaining_vrtx = vertices_set (\%graph);
$i = 0;

while (scalar @remaining_vrtx > 0)
{
  # identify the source vertices
  my @sources;
  foreach (keys %graph)
  {
    push (@sources, $_) if (not exists $rgraph{$_});
  }

  if (scalar @sources > 0)
  {
    $final_scores[$i++] = \@sources;

    foreach my $source (@sources)
    {
      delete $graph{$source};
      foreach (keys %rgraph)
      {
	@{$rgraph{$_}} = grep { $_ ne $source } @{$rgraph{$_}};
	delete $rgraph{$_} if (scalar @{$rgraph{$_}} == 0);
      }
      @remaining_vrtx = grep { $_ ne $source } @remaining_vrtx;
    }
  }
  else
  {
    my @t = @remaining_vrtx;
    $final_scores[$i] = \@t;
    @remaining_vrtx = ();
  }
}

print "\033[01mResult:\033[0m\n";
$i = 0;
foreach (@final_scores)
{
  print ("#".($i + 1).":");
  if (scalar @{$_} > 1)
  {
    print " TIE:";
    my $c = 0;
    for (my $j = 0; $j < scalar @{$_}; $j++)
    {
      if ($c)
      {
	print ",";
      }
      else
      {
	$c = 1;
      }
      print " $num2ids{@{$_}[$j]}";
    }
    print "\n";
  }
  else
  {
    print " $num2ids{@{$_}[0]}\n";
  }
  $i++;
}
exit 0;
