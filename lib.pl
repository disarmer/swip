#! /usr/bin/perl
use strict;
use warnings;
use Image::Magick;	#http://www.imagemagick.org/script/perl-magick.php
use List::Util qw(max);

$0=~m#(.*)/.*?#;
my $root=$1;
our ($dbh,$cwd,$quality,$gentle,$version);

sub url_encode{
	local @_=@_;
	map{ s#([^A-Za-z0-9\-/.])#sprintf("%%%02X", ord($1))#seg} @_;
	return wantarray?@_:join("\n",@_);
}
sub html_entity{
	local @_=@_;
	map{
		$_='' unless defined $_;
		@{$_}=&html_entity(@{$_}) if ref $_;
		s/&/&amp;/g;s/"/&quot;/g;s/</&lt;/g;s/>/&gt;/g;s/'/&#39;/g
	} @_;
	return wantarray?@_:join("\n",@_);
}
sub sort_by_length{
	my @arr;
	for(sort{length(decode_utf8($_[$a])) <=> length(decode_utf8($_[$b]))} 0..$#_){
		push @arr,$_[$_];
	}
	return(@arr);
}
sub str_to_file{
	my($fileout,$str)=@_;
	unlink($fileout);
	open FO, ">",$fileout or die "can't open output file $!";
	print FO $str;
	close FO;
}
sub load_image{
	my $source=shift;
	my $image=Image::Magick->new();
	my $w=$image->Read($source);
	warn $w if $w;
	exit if $w=~ m/^Exception/;
	my ($width, $height)=$image->Get('width', 'height');
	return ($image,$width,$height);
}
sub html_write{
	my ($ref,$html_album_desc,$num_per_page)=@_;
	$num_per_page||=20;
	my @images_for_html=@$ref;
	@images_for_html=grep{! m#/thumbs/#}sort @images_for_html;
	if(scalar @images_for_html<1){return}

	$_=$html_album_desc;s/'/&#39;/g;
	$html_album_desc=&html_entity($html_album_desc);

	my $html_head_str="<!DOCTYPE html><html xmlns='http://www.w3.org/1999/xhtml'>
<head>
	<meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
	<title>$html_album_desc</title>
	<meta name='description' content='$_'/>
	<meta name='generator' content='swip v$version'/>
	<meta name='keywords' content='foto, photo, gallery, photos, images'/>
	<link rel='icon' href='/favicon.ico' type='image/x-icon'/>
	<script type='text/javascript' src='/js/iLoad/iLoad.js'></script>
	<style type='text/css'>
		html{background:url(/js/iLoad/film.png) 100% 0 repeat-y,url(/js/iLoad/film.png) 0 0 repeat-y;background-color:#000;}body{padding:0 80px;text-align:center;}a img{margin-bottom:30px}#photos img{width:90%;margin:2em 0}div#nav{position:fixed;bottom:0;right:0;margin:0;padding:6px 20px 6px 20px;background-color:#fff;border-top:1px solid #000;border-left:1px solid #000;border-radius:20px;-moz-border-radius:20px;-webkit-borderd-radius:20px;}div#nav a{float:left;background-color:#ccc;padding:0 10px;margin:0 7px;border:1px solid #000;text-decoration:none;font-weight:bold;}div#nav a:hover{background-color:#cc0;}
	</style>
</head><body>";
	for(my $file_num=1;$file_num<1+($#images_for_html+1)/$num_per_page;$file_num++){
		my $fileout="$file_num.html";
		print "Writing to file: $fileout\n";
		unlink($fileout);
		my $out=$html_head_str."<div id='nav'>";
		for(my $menu_num=1;$menu_num<1+($#images_for_html+1)/$num_per_page;$menu_num++){
			$out.="<a href='$menu_num.html'>$menu_num</a>";
		}
		$out.="</div><div id='photos'>";
		for my $href_num(0..$num_per_page-1){
			my $href=$images_for_html[$href_num+($file_num-1)*$num_per_page]||last;
			$href=~s/\Q$cwd\E//;
			$href=&url_encode($href);
			$out.="<img alt='photo' src='$href' onclick='this.style=\"display:none\";'/>";
		}
		$out.="</div></body></html>";
		&str_to_file($fileout,$out);
	}
	my $out=$html_head_str;
	$out.="<div id='thumbs'>";
	for(my $file_num=0;$file_num<$#images_for_html+1;$file_num++){
		my $href=$images_for_html[$file_num];
		$href=~s/\Q$cwd\E//;
		my $thumb=$href;
		$thumb=~s#(.*)/(.*)#$1/thumbs/$2# or $thumb="thumbs/$thumb";
		($href,$thumb)=&url_encode($href,$thumb);
		$out.="<a href='$href' rel='iLoad|ph'><img alt='photo' src='$thumb.thumb'/></a>";
	}
	$out.="</div></body></html>";
	$out=~tr/\n\t\r//d;
	&str_to_file('index.html',$out);
}
sub binn{
	my $source=shift;
	my $dest=$source;
	my $bin_size=shift||2;
	&report("Binn $bin_size : $source",4);

	my ($image,$width,$height)=&load_image($source);
	my $crop_flag=0;
	my $new_width=int($width/$bin_size);
	if ($width!=$new_width*$bin_size){
		$crop_flag=1;
	}
	my $new_height=int($height/$bin_size);
	if ($height!=$new_height*$bin_size){
		$crop_flag=1;
	}
	if($gentle){
		if(sqrt($new_height**2+$new_width**2)<1500){
			&report("$source not processed, diagonal size ".int(sqrt($new_height**2+$new_width**2)),2);
			return;
		}
	}
	$image->Resize('filter'=>'box','geometry'=>'geometry', 'width'=>$new_width,'quality'=>$quality, 'height'=>$new_height);
	$image->Crop('x'=>0, 'y'=>0);#Задаем откуда будем резать
	$image->Crop($new_width*$bin_size."x".$new_height*$bin_size);#С того места вырезаем
	$image->Set('quality'=>$quality);
	$image->Write($dest);
}
sub resize{
	my $source=shift;
	my $dest=$source;
	my $target_size=shift||1600;

	&report("$source resize to: $target_size",4);
	my ($image,$width,$height)=&load_image($source);

	if($gentle){
		if($target_size=~m/%/){
		}elsif($target_size>=$width&&$target_size>=$height){
			&report("$source отказ от увеличения",2);
			return;
		}
	}
	$image->Resize('geometry'=>$target_size."x".$target_size,'quality'=>$quality);
	$image->Set('quality'=>$quality);
	$image->Write($dest);
}
sub thumb{
	my $source=shift;
	my $dest=$source;
	return if $source=~m#/thumbs/#;
	$dest=~s#(.*)/(.*)#$1/thumbs/$2#;
	$dest.='.thumb';
	mkpath("$1/thumbs/", 0755);

	my $square=shift||0;
	my $target_size=shift||150;

	&report("thumb size: $target_size $dest $square",4);
	my ($image,$width,$height)=&load_image($source);
	my $bg=$image->clone();
	my $min_geom=$width>$height?$height:$width; #minimal
	if($width>$height){
		$bg->Crop('x'=>($width-$min_geom)/2, 'y'=>0);
		$bg->Crop($min_geom+(($width-$min_geom)/2)."x".$min_geom);
	}else{
		$bg->Crop('x'=>0, 'y'=>($height-$min_geom)/2);
		$bg->Crop($min_geom."x".($min_geom+($height-$min_geom)/2));
	}
	$bg->Resize('geometry'=>$target_size."x".$target_size);

	if($square){
		if($square==2){
			my $empty=Image::Magick->new('size'=>$target_size);
			$empty->Read('xc:transparent');
			my ($mask,undef,undef)=&load_image("$root/misc/thumb_mask.png");
			$mask->Resize('geometry'=>$target_size."x".$target_size);
			$bg->Composite('image'=>$mask, 'compose'=>'CopyOpacity', 'gravity'=>'Center');
		}else{
			$bg->UnsharpMask('radius'=>1.5, 'sigma'=>1.5, 'amount'=>1.2, 'threshold'=>0);
		}
	}else{
		$image->Resize('geometry'=>($target_size*0.95)."x".($target_size*0.95));
		$image->UnsharpMask('radius'=>1.5, 'sigma'=>1.5, 'amount'=>1.2, 'threshold'=>0);
		$bg->Blur('radius'=>6,'sigma'=>7);
		$bg->Composite('image'=> $image, 'compose'=>"Over", 'gravity'=>"Center");
	}
	$bg->Set('compression'=>'LZW' ,'quality'=>$quality);

	if($square==2){
		$bg->Write("png:$dest");
	}else{
		$bg->Write("jpg:$dest");
		&erase_exif($dest);
	}
}
sub erase_exif{
	my $source=shift;
	my $dest=$source;
	&report("erase_exif $source",4);
	my $exifTool=new Image::ExifTool;
	$exifTool->SetNewValue("*");
	$exifTool->WriteInfo($dest);
}
sub histogram{
	my $source=shift;
	return if $source=~m/\.hist$/;
	&report("histogram $source",4);
	my ($image,$width,$height)=&load_image($source);
	my @output;
	#for($image->GetPixels(,'height'=>$height, 'width'=>$width,'normalize'=>1)){
	for my $j(0..$height-1){
		for my $i(0..$width-1){
			my @pixel = $image->GetPixel('x'=>$i,'y'=>$j);
			$output[0][$pixel[0]*255]++;
			$output[1][$pixel[1]*255]++;
			$output[2][$pixel[2]*255]++;
			#my $val=sprintf("%.0f",($pixel[0]+$pixel[1]+$pixel[2])*255/3);
			$output[3][($pixel[0]+$pixel[1]+$pixel[2])*255/3+0.5]++;
		}
	}
	my $max=0;
	for(my $index=0;$index<255;$index++){
		$max=max($max,$output[0][$index]||0,$output[1][$index]||0,$output[2][$index]||0,$output[3][$index]||0);
	}
	my @data = ([0..255],$output[0],$output[1],$output[2],$output[3]);
	my $obj;
	$obj=Chart::Lines->new(888,300);
	$obj->set('title' =>'',
		'legend' => 'none',
		'brush_size' => 3,
		'x_ticks' => 'vertical',
		'tick_len' => 2,
		'max_val' => $max,
		'min_val' => 0,
		'skip_x_ticks' => 16,
		'max_y_ticks' => 10,
		'grid_lines' => 'true',
		'grey_background' => 'false',
		'graph_border' => 5,
		'colors' => {'background' => [232,248,252],
			'x_grid_lines' => [155,186,214],
			'y_grid_lines' => [155,186,214],
			'text' => [34,34,102],
			'y_label' => [34,34,102],
			'dataset0' => [255,0,0],
			'dataset1' => [0,255,0],
			'dataset2' => [0,0,255],
			'dataset3' => [0,0,0]
		}
	);
	$obj->png($source.".hist",\@data);
}
sub sign{	#Качество Масштаб_надписи Прозрачность Текст [угол]
	my $source=shift;
	my $dest=$source;#shift;
	my $string=shift||"disarmer.ru";
	my $scale=shift||4;
	my $color=shift||"ffffff";
	$color="#$color" unless $color=~m/#/;
	my $angle=shift||270;

	#if($#_+1){$angle=shift}else{$angle=270}
	while($angle<0){
		$angle+=360;
	}
	while($angle>=360){
		$angle-=360;
	}
	my $font="$root/misc/default.ttf";
	#my $color="#ffffff$alpha";

	my ($image,$width,$height)=&load_image($source);
	my $diag=sqrt($width**2+$height**2);
	my $pointsize=(0.5+$scale/6)*$diag/50;
	my $kerning=(0.5+$scale/6)*$diag/200;

	&report("sign $source : $string",4);

	my $label=Image::Magick->new('size'=>&get_font_geometry($pointsize,$font,$string));
	$label->Read('xc:transparent');
	$label->Annotate('x'=>0,'y'=>-$pointsize/7, 'fill'=>$color, 'font'=>$font, 'pointsize'=>$pointsize, 'gravity'=>"SouthWest", 'text'=>"$string", 'kerning'=>$kerning,'antialias'=>'true');

	my $shadow=new Image::Magick();
	$shadow=$label->Clone();
	$shadow->Shadow('geometry'=>'100x3+0+0');#, 'x'=>integer, 'y'=>integer);

	$shadow->Negate();
	$shadow->Composite('image'=> $label, 'compose'=>"Blend", 'gravity'=>"Center");
	$label=$shadow;
	undef $shadow;

	$label->Rotate('degrees'=> $angle,'background'=>'transparent');
	$image->Composite('image'=>$label,'gravity'=>"SouthEast",'x'=>0,'y'=>$pointsize/2, 'compose'=>'dissolve', 'tile'=>"False");

	$image->Set('quality'=>$quality);
	$image->Write($dest);
	undef $image;
}
sub get_font_geometry{#Тогда можно через QueryFontMetrics узнать информацию о графическом представлении строки и потом на её основе вычислить координаты.
	my $pointsize=shift;
	my $font=shift;
	my $string=shift;
	my ($width,$height,$x_ppem, $y_ppem, $ascender, $descender, $max_advance, $predict);
	my $image=new Image::Magick;

	my $num_rows=1;
	if($string=~m/\\n/){
		my @arr=split("\\\\n", "$string");
		$num_rows=$#arr*2;
		for(sort{length(decode_utf8($arr[$a])) <=> length(decode_utf8($arr[$b]))}0..$#arr){
			#print "$arr[$_]: ".length(decode_utf8($arr[$_]))."\n";
		}
		($string)=@arr;
	}

	$image->Set('size'=>"300x500", 'pointsize'=>$pointsize, 'font'=>$font, 'antialias'=>'true', 'density'=>"50x50");
	$image->Read('xc:none');
	($x_ppem, $y_ppem, $ascender, $descender, $width, $height, $max_advance)=$image->QueryFontMetrics('text'=>$string);
	$width*=3.15;
	return ($width.'x'.($height*$num_rows));
}
sub photo_db_connect{
	&report("Подключаемся к базе данных",9);
	$dbh=DBI->connect("dbi:Pg:dbname=disarmer;host=localhost;", @_);
	return $dbh;
}
sub photo_db_destroy{
	$dbh||=&photo_db_connect();
	my $sth=$dbh->prepare("drop table if exists photo;");
	$sth->execute;
	$sth=$dbh->prepare("create table photo(
		id serial not null,
		dir varchar(500),
		filename varchar(500),
		size_x smallint,
		size_y smallint,
		iso smallint,
		aperture real,
		speed real,
		fov real,
		model varchar(20),
		size integer,
		time timestamp(0),
		time_mod timestamp(0),
		md5 varchar(32),
		CONSTRAINT id PRIMARY KEY (id)
	);");
	$sth->execute;
}
sub index{
	my $file=$_=shift;
	my $dbh=shift||die $!;#||&photo_db_connect();
	s/\Q$cwd\E//;
	$_='./'.$_ unless m#/#;
	m#(.*)/(.*)#;
	my ($directory,$filename)=($1,$2);
	&report("$directory\t\t$filename",7);#sleep 1;return;
	my $info=ImageInfo($file);

	my $time_mod=str2time($$info{"FileModifyDate"});
	my $time=(str2time($$info{"DateTimeOriginal"}))||$time_mod;

	$time=localtime($time);
	$time_mod=localtime($time_mod);

	my $iso=int ($$info{"ISO"}||'0');
	my $aperture=0+($$info{"Aperture"}||'0');
	my $shutter_speed=1/eval($$info{"ExposureTime"}||99999999);
	my $fov=$$info{"FOV"}||'0';
	$fov=0+(split ' ',$fov)[0];
	my $model=$$info{"Model"}||"unknown";
	$model=substr $model,0,20;

	my (undef,$size_x,$size_y)=&load_image($file)||warn "$file have wrong format!"&&return;

	my $md5=md5_hex($file);
	my $filesize=-s "$file";
	#my @stat=stat($file);

	my $sthi=$dbh->prepare_cached("insert into photo (dir, filename,size_x,size_y, size, md5,time,time_mod,iso,aperture,speed,fov,model) values (?,?,?,?,?,?,?,?,?,?,?,?,?);");
	$sthi->execute($directory,$filename,$size_x,$size_y,$filesize,$md5,$time,$time_mod,$iso,$aperture,$shutter_speed,$fov,$model)||die $!;
}
1
