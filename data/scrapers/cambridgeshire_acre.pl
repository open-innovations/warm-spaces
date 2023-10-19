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


	# Build a web scraper
	my $res = scraper {
		process '.elementor-icon-list-item .elementor-icon-list-text', "warmspaces[]" => 'TEXT';
	}->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		if($res->{'warmspaces'}[$i] =~ /^(.*?)[\s\t]+- (.*)$/){
			$d = {};
			$d->{'title'} = $1;
			$content = $2;
			if($content =~ s/Opens(\s|\&nbsp;)?:(\s|\&nbsp;)?(.*?)$//i){ $d->{'hours'} = parseOpeningHours({'_text'=>parseText($3)}); }
			$d->{'address'} = $content;
			$d->{'description'} = "Part of the Cambridgeshire Community Hubs Network.";
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

