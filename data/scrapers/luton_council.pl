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
	@days = ("Mon","Tue","Wed","Thu","Fri","Sat","Sun");

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$json->{'hits'}{'hits'}}; $i++){
		$warmspace = $json->{'hits'}{'hits'}[$i];
		$ws = 0;
		for($c = 0; $c < @{$warmspace->{'_source'}{'offering'}}; $c++){
			if($warmspace->{'_source'}{'offering'}[$c] eq "Warm Space"){
				$ws = 1;
			}
		}
		if($ws){
			$d = {};
			$d->{'title'} = $warmspace->{'_source'}{'tag'};
			$d->{'description'} = $warmspace->{'_source'}{'description'};
			$d->{'address'} = $warmspace->{'_source'}{'venue'}{'address'};
			$d->{'lat'} = $warmspace->{'_source'}{'venue'}{'geopoint'}{'lat'};
			$d->{'lon'} = $warmspace->{'_source'}{'venue'}{'geopoint'}{'lon'};
			if($warmspace->{'_source'}{'venue'}{'postcode'}){ $d->{'address'} .= ($d->{'address'} ? ", ":"").$warmspace->{'_source'}{'venue'}{'postcode'}; }
			$d->{'hours'} = {'_text'=>'','opening'=>''};
			for($dy = 0; $dy < @days; $dy++){
				$day = $days[$dy];
				if($warmspace->{'_source'}{'openingHours'}{$day}{'start'}){
					$d->{'hours'}{'_text'} .= ($d->{'hours'}{'_text'} ? " ":"").$day." $warmspace->{'_source'}{'openingHours'}{$day}{'start'}-$warmspace->{'_source'}{'openingHours'}{$day}{'end'};";
				}
			}
			if($d->{'hours'}{'_text'}){ $d->{'hours'} = parseOpeningHours($d->{'hours'}); }

			if($warmspace->{'_source'}{'phone'}){ $d->{'contact'} .= ($d->{'contact'} ? " ":"")."Tel: ".$warmspace->{'_source'}{'phone'}; }

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

