#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
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

	if($str =~ /var markers = (.*)/){
		$json = $1;
		$json =~ s/\;$//g;
		$json = readJSON($json);

		for($i = 0; $i < @{$json->{'array'}}; $i++){
			$d = {};
			$d->{'title'} = $json->{'array'}[$i]{'title'};
			$d->{'url'} = $json->{'array'}[$i]{'url'};
			$d->{'address'} = $json->{'array'}[$i]{'address'};
			$d->{'lat'} = $json->{'array'}[$i]{'lat'};
			$d->{'lon'} = $json->{'array'}[$i]{'lng'};
			$d->{'description'} = $json->{'array'}[$i]{'info'};			
			$d->{'hours'} = parseOpeningHours({'_text'=>$json->{'array'}[$i]{'date'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }

			# Store the entry as JSON
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


sub readJSON {
	$json = shift();
	
	if(!$json){ $json = "{}"; }
	eval {
		$json = JSON::XS->new->decode($json);
	};
	if($@){ warning("\tInvalid JSON.\n".$json); }
	if(ref($json) eq "ARRAY"){
		$json = {'array'=>\@{$json}};
	}
	return $json;	
}

