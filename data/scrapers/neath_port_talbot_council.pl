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

	if($str =~ /window.warmSpaces.searchResults = (.*?)window.warmSpaces/s){
		$str = $1;

		# Fix JSON
		$str =~ s/\'/\"/sg;
		$str =~ s/[\r]//sg;
		$str =~ s/(\n\s{2,}),/,$1/g;
		$str =~ s/(\n\s{2,})([A-Za-z0-9\-]+) ?\:/$1\"$2\":/g;

		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);	

		for($i = 0; $i < @{$json->{'features'}}; $i++){
			$area = $json->{'features'}[$i];
			$area->{'properties'}{'openingHours'} =~ s/\r\n/ /g;
			$d = {};
			$d->{'lat'} = $area->{'geometry'}{'coordinates'}[1];
			$d->{'lon'} = $area->{'geometry'}{'coordinates'}[0];
			$d->{'title'} = $area->{'properties'}{'name'};
			$d->{'address'} = $area->{'properties'}{'address'};
			$d->{'hours'} = parseOpeningHours({'_text'=>$area->{'properties'}{'openingHours'}});
			$d->{'url'} = "https://www.npt.gov.uk/business/npt-warm-spaces/business-profile/?b=".$area->{'properties'}{'id'};

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

