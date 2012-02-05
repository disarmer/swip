#!/usr/bin/perl -w
=head1
this tool for automated testing of swip perfomance.
use it with attention.
=cut
use strict;
use Time::HiRes qw(time);
use Data::Dumper;
$0=~m#(.*)/.*?#;
my $root=$1;
my $max_forks=16;

my %results;
my %modes=(	'typical using'	=>'-q 90 -b 2 -s swip 6 ff08 -r 900 -t 2',
		'signing'	=>'-s swip 6 ff08',
		'resizing'	=>'-r 900 -q 75',
	    	'binning'	=>'-b 3 -q 75',
		#'histogram'	=>'-hi',
	    	'thumbnails'	=>'-t 2');
for my $mode(keys %modes){
    my @results;
    print '='x40," Testing mode: $mode ",'='x40,"\n";
    for my $con(0..$max_forks){
	mkdir "$root/test";
	for(1..30){
	    `cp "$root/example.jpg" "$root/test/example_$_.jpg"`;
	}
	print "Starting test with $con processes\n";
	my $time_s=Time::HiRes::time;
	`cd "$root/test";/home/disarmer/sh/swip/swip.pl $modes{$mode} -c $con`;
	my $time_e=Time::HiRes::time-$time_s;
	push @results,$time_e;
    }
    print "Concurrency		time\n";
    for(0..$#results){
	printf("%i 			%.3f s\n",$_,$results[$_]);
    }
    $results{$mode}=\@results;
}
use File::Path;
rmtree "$root/test";
#print Dumper %results

#build graph
use Chart::Lines;
my @data = ([0..$max_forks]);
my @legends=keys %results;
for(@legends){
    push @data,$results{$_};
}
my $obj=Chart::Lines->new(1200,900);
$obj->set('title' =>'',
	'brush_size' => 5,
	'tick_len' => 2,
	'x_label'=>'concurrency',
	'y_time'=>'concurrency',
	'legend_labels' => \@legends,
	'min_val' => 0,
	'skip_x_ticks' => 0,
	'max_y_ticks' => 10,
	'grid_lines' => 1,
	'grey_background' =>1,
	'graph_border' => 0
);
$obj->png("$root/performance.png",\@data);