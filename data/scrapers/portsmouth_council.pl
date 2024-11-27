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
	$json = join("",@lines);

	if(!$json){ $json = "{}"; }
	eval {
		$json = JSON::XS->new->decode($json);
	};
	
	for($m = 0; $m < @{$json->{'markers'}} ; $m++){
		$d = {};
		$d->{'title'} = $json->{'markers'}[$m]{'title'};
		$d->{'address'} = $json->{'markers'}[$m]{'address'};
		$d->{'lon'} = $json->{'markers'}[$m]{'lng'};
		$d->{'lat'} = $json->{'markers'}[$m]{'lat'};
		if($json->{'markers'}[$m]{'description'} =~ /href="([^\"]+)"/){
			$d->{'url'} = $1;
		}
		$desc = $json->{'markers'}[$m]{'description'};
		$hours = "";
		while($desc =~ s/<p>(.*?)<\/p>//){
			$line = $1;
			if($line =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|holidays)/){
				$hours .= ($hours ? "; ":"").$line;
			}
		}
		if($hours){
			$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
		}

		push(@entries,makeJSON($d,1));
	}
	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

