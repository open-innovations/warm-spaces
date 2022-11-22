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

#	$str =~ s/[\n\r]/ /g;
#	$str =~ s/[\s]{2,}/ /g;
#	$str =~ s/\&nbsp;/ /g;

	if($str =~ /var WPBDP_googlemaps_data = (.*);\n/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);	

		for($i = 0; $i < @{$json->{'map_0'}{'locations'}}; $i++){
			$d = $json->{'map_0'}{'locations'}[$i];
			$d->{'lat'} = $d->{'geolocation'}{'lat'};
			$d->{'lon'} = $d->{'geolocation'}{'lng'};
			delete $d->{'content'};
			delete $d->{'geolocation'};
			push(@entries,makeJSON($d,1));
		}
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

