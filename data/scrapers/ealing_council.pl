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

	$json = JSON::XS->new->decode($str);	

	for($i = 0; $i < @{$json}; $i++){
		$place = $json->[$i];
		$d = {};
		if($place->{'title'}){
			$d->{'lat'} = $place->{'lat'};
			$d->{'lon'} = $place->{'lng'};
			$d->{'title'} = $place->{'title'};
			$d->{'address'} = $place->{'address'};
			$d->{'url'} = $place->{'URL'};
			if($place->{'phone'}){ $d->{'contact'} = "Tel: $place->{'phone'}"; }

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

