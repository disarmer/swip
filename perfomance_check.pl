#!/usr/bin/perl -w
=head1
this tool for automated testing of swip perfomance.
use it with attention.
=cut

use strict;
use Time::HiRes qw(time);

my @results;
for(0..12){
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
1 			135.370 s
2 			134.900 s
3 			115.994 s
4 			83.645 s
5 			83.889 s
6 			85.475 s
7 			84.818 s
8 			84.218 s
9 			85.583 s
10 			86.078 s
11 			86.131 s
12 			85.515 s