#!/usr/bin/perl -w
use strict;
use Cwd;
use File::Find;
use Data::Dumper;
use Module::Load;
use Term::ANSIColor qw(:constants);
our $cwd=cwd.'/';
our $version=0.1;

use Getopt::Long;
my %opts;
my (@resize,@thumb,@html,@binn,@erase_exif,@sign,$filter);
GetOptions(	"quality=i"	=>\$opts{'quality'},
		"concurrent=i"	=>\$opts{'concurrent'},
		"gentle"	=>\$opts{'gentle'},
		"filter=i"	=>\$opts{'filter'},
		"st|selftest"	=>\$opts{'selftest'},
		"h|html=s{0,2}"	=>\@{$opts{'html'}},
		"histogram"	=>\@{$opts{'histogram'}},
		"index=s{0,2}"	=>\@{$opts{'index'}},
		"thumb=i{0,2}"	=>\@{$opts{'thumb'}},
		"resize=s"	=>\@{$opts{'resize'}},
		"binn=i"	=>\@{$opts{'binn'}},
		"erase_exif"	=>\@{$opts{'erase_exif'}},
		"s|sign=s{0,4}"	=>\@{$opts{'sign'}});

our $quality = $opts{'quality'}||90;
our $gentle = $opts{'gentle'};
$0=~m#(.*)/.*?#;
my $root=$1;

my @actions;
for my $act( qw/binn resize erase_exif sign thumb index histogram/){
	if(defined @{$opts{$act}}){
		push @actions,[$act,$opts{$act}];
	}
}

if(defined $opts{'selftest'}){
	open SELF,'<',$0;
	open LIB,'<',"$root/lib.pl";
	for(<SELF>,<LIB>){
		m/\b(use|load)\s+(\w+::[\w:]+)/ or next;
		eval "use $2";
		if($@){
			print "Error: module not loaded:	$2\n";
		}else{
			print "module OK |	$2\n";
		}
	}
	exit;
}
unless(@actions or defined @{$opts{'html'}}){
	for(<DATA>){print}
	print "\n\n";
	exit;
}
if(defined @{$opts{'index'}}){
	load DBI;
	load Date::Parse;
	load Digest::MD5, 'md5_hex';
}

if(defined @{$opts{'thumb'}}){
	load File::Path,'mkpath';
	load File::Basename,'dirname';
}
if(defined @{$opts{'erase_exif'}} or defined @{$opts{'thumb'}} or defined @{$opts{'index'}}){
	load Image::ExifTool, 'ImageInfo',':Public';
}
if(defined @{$opts{'sign'}}){
	load Encode, 'decode_utf8';
}
if(defined @{$opts{'histogram'}}){
	load Chart::Lines;
}


sub report{
	my $arg=shift;
	my $level=pop||5;	# 1-9 - greater means more important
	$arg.=' '.join(' ',@_);
	$_=$level;
	if	($_ eq 1)	{$_=BLACK}
	elsif	($_ lt 4)	{$_=BOLD.BLACK}
	elsif	($_ eq 4)	{$_=BOLD}
	elsif	($_ eq 5)	{$_=WHITE}
	elsif	($_ eq 6)	{$_=CYAN}
	elsif	($_ eq 7)	{$_=YELLOW}
	elsif	($_ eq 8)	{$_=MAGENTA}
	elsif	($_ eq 9)	{$_=BLINK.RED}
	print $_,$arg,RESET,"\n";
}

find({'wanted'=>\&found,'follow'=> 1},cwd);
my @files;
sub found{
	$_=$File::Find::name;
	return unless -f $_;
	return unless m/\.(jpg|bmp|gif|png)/i;
	push @files, $_;
}

if($opts{'filter'}){
	@files=grep {$opts{'filter'}*1024 <= ($opts{'filter'}>0?1:-1)* -s $_} @files; #@//
}

require "$root/lib.pl";

if(defined @{$opts{'html'}}){
	&html_write(\@files,@{$opts{'html'}});
}
exit unless @actions;
my $dbh;
if(defined @{$opts{'index'}}){
	$dbh=&photo_db_connect(@{$opts{'index'}});
	&photo_db_destroy($dbh);
}
my @jobs;
for(@files){
	push @jobs,$_;
}
my $concurrent;
if(defined $opts{'concurrent'}){
	$concurrent=abs int $opts{'concurrent'};
}else{
	$_=`free -m`;
	m/Mem:\s+(\d+)/;
	$concurrent=int (($1+600)/1024);
}
$concurrent=16 if $concurrent>16;
&report("Run $concurrent concurrent processes",9);

$SIG{'CHLD'} = sub{wait;&sig_child};
&sig_child for(1..$concurrent);

$SIG{'HUP'} = sub{warn $concurrent};

if($concurrent eq 0){
	while(my $file=shift @jobs){
		for(@actions){
			#warn Dumper $file,$_;
			my($act,$ref)=@$_;
			if($act eq 'index'){
				$ref=[$dbh->clone];
			}
			local $_;
			$main::{$act}($file,@$ref);
		}
	}
}

while($concurrent){
	wait and $concurrent-- if $concurrent;
}
print "END\n";


sub sig_child{
	my $file=shift @jobs or return;
	$concurrent++;
	fork and return;
	for(@actions){
		my($act,$ref)=@$_;
		if($act eq 'index'){
			$ref=[$dbh->clone];
		}
		local $_;
		$main::{$act}($file,@$ref);
	}
	exit;
}

__END__
SWIP - simple web image processor
	Valid arguments:
	-q,  --quality
		Output jpeg quality(1-100), default 92

	-b,  --binn	FACTOR
		reduce images multiple value of FACTOR with box filter

	-r,  --resize	SIZE
		resize every image to fit SIZE

	-t,  --thumb	SQUARE	SIZE
		make thumbnails of images

	-e,  --erase_exif
		erase EXIF info from all images, reducing their size

	-h,  --html	NAME	IMAGES_PER_PAGE
		write html pages for images with defined album name

	-hi, --histogram
		get and build hystogram for every image

	-s,  --sign	TEXT SIZE COLOR ANGLE
		add watermark to images

	-f,  --filter	+-SIZE
		use only images that FILESIZE greater(+) or lower(-) kB

	-i,  --index
		index every image info and write result in SQL database

	-c,  --concurrent	NUM
		number of concurrent worker processes, default is auto beetwen 1 and 12

	-g,  --gentle
		do not enlarge small images and do not resize images to so very small size

	-st, --selftest
		try to load needed modules and exits
