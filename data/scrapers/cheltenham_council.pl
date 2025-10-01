#!/usr/bin/perl

use lib "./";
use utf8;
use Data::Dumper;
use Web::Scraper;
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

	if($str =~ /<h3><strong>Warm places<\/strong><\/h3>(.*)<h2>/s){
		$str = $1;
	}
	
	while($str =~ s/\n\t<li>(.*?)\n\t<\/li>//s){
		$d = {};
		$li = $1;
		if($li =~ s/<ul>(.*)<\/ul>//s){
			$ul = $1;
		}
		if($li =~ /<a href="([^\"]*)"[^\>]*>/){
			$d->{'url'} = $1;
		}
		$li =~ s/<[^\>]*>//g;
		if($li =~ /([^\,]*)\, (.*)/){
			$d->{'title'} = $1;
			$d->{'address'} = $2;
		}
		if($ul =~ s/<li>Open (.*?)<\/li>//){
			$d->{'hours'} = {};
			$d->{'hours'}{'_text'} = $1;
			$d->{'hours'}{'_text'} =~ s/<[^\>]+>//g;
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
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

