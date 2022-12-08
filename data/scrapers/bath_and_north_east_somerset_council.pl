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


	while($str =~ s/<div[^\>]*class="geolocation-location js-hide"[^\>]*data-lat="([^\"]*)"[^\>]*data-lng="([^\"]*)"[^\>]*data-label="([^\"]*)"[^\>]*>(.*?)<\/div><\/div>//s){
		$d = {'lat'=>$1+0,'lon'=>$2+0,'title'=>$3};
		$content = $4;
		
		if($content =~ /<p class="address[^\>]*>(.*?)<\/p>/s){
			$d->{'address'} = $1;
			$d->{'address'} =~ s/(^\s|\s$)//g;
			$d->{'address'} =~ s/<[^\>]*>//g;
		}
		if($content =~ /<a[^\>]*href="([^\"]+)"/){
			$d->{'url'} = $1;
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://livewell.bathnes.gov.uk".$d->{'url'}; }
			
		}
		
		# Store the entry as JSON
		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

