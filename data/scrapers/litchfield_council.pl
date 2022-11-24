#!/usr/bin/perl

use lib "./";
use utf8;
use Web::Scraper;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';

# Get the file to process
$file = $ARGV[0];

# If the file exists
if(-e $file){

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	$str =~ s/[\n\r]+/\n/s;

	@entries = ();
	

	while($str =~ s/inMyAreaGMapMarker\[[0-9]+\] = createMarker\([^\(]*google.maps.LatLng\(([0-9\.\-\+\,]+?), ([0-9\.\-\+\)]+?)\).*?<a[^\>]*href="([^\"]+)">(.*?)<\/a>.*?\)//s){
		$d = {'lat'=>sprintf("%0.5f",$1)+0,'lon'=>sprintf("%0.5f",$2)+0,'url'=>$3,'title'=>parseText($4)};
		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

