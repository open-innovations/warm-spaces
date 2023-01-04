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

	while($str =~ s/<div class="elementor-element [^>]*>.*?<span class="elementor-icon-list-text"><b>(.*?)<\/b><\/span>.*?<div class="elementor-element [^\>]*>.*?<span class="elementor-icon-list-text">(.*?)<\/span>//s){
		$d = {};
		$d->{'title'} = $1;
		$content = $2;
		if($content =~ s/Venue(\s|\&nbsp;)?:(\s|\&nbsp;)?(.*?)</</i){ $d->{'address'} = parseText($3); }
		if($content =~ s/Notes(\s|\&nbsp;)?:(\s|\&nbsp;)?(.*?)(<|$)/$4/i){ $d->{'description'} = parseText($3); if($d->{'description'} eq "-"){ delete $d->{'description'}; } }
		if($content =~ s/Opening Times(\s|\&nbsp;)?:(\s|\&nbsp;)?(.*?)</</i){ $d->{'hours'} = parseOpeningHours({'_text'=>parseText($3)}); }
		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

