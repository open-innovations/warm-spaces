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

	if($str =~ /<script type="text\/json" id="map_json">(.*?)<\/script>/s){

		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);	

		for($i = 0; $i < @{$json}; $i++){
			$d = {};
			$d->{'title'} = $json->[$i]{'title'};
			$d->{'url'} = "https://www.barnet.gov.uk".$json->[$i]{'url'};
			$d->{'lat'} = $json->[$i]{'latitude'}+0;
			$d->{'lon'} = $json->[$i]{'longitude'}+0;
			$d->{'address'} = join(", ",@{$json->[$i]{'address'}});

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

