#!/usr/bin/perl -w
=head1
this tool for automated testing of swip perfomance.
use it with attention.
=cut

use strict;
use Time::HiRes qw(time);

my @results;
for(0..16){
    `mkdir test; cp ./img/* test/;`;
    my $time_s=Time::HiRes::time;
    print "Starting test with $_ processes\n";
    `cd test;/home/disarmer/sh/swip/swip.pl -q 90 -b 2 -s swip 6 ff08 -r 900 -t 2 -c $_`;
    my $time_e=Time::HiRes::time-$time_s;
    push @results,[$_,$time_e];
    `rm test -r`;
}

print "\nResults\n";
print "Concurrency		time\n";
for(@results){
    printf("%i 			%.3f s\n",@$_);
}
__END__
Results
Concurrency		time
0 			57.703 s
1 			114.534 s
2 			114.891 s
3 			92.635 s
4 			60.779 s
5 			60.281 s
6 			75.165 s
7 			58.237 s
8 			58.014 s
9 			58.356 s
10 			58.291 s
11 			58.324 s
12 			59.339 s
13 			59.032 s
14 			58.686 s
15 			58.765 s
16 			60.159 s