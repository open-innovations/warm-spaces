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


	@entries;

	while($str =~ s/<div class="content">(.*?)<\/div>//s){
		$content = $1;

		while($content =~ s/<p>(.*?)<\/p><ul>(.*?)<\/ul>//s){
			$d = {'title'=>parseText($1)};
			$ul = $2;
			@li = ();
			while($ul =~ s/<li>(.*?)<\/li>//s){
				push(@li,$1);
			}
			$d->{'address'} = $li[0];
			if($li[1]=~ /Opening/){ $d->{'hours'} = parseOpeningHours({'_text'=>parseText($li[1])}); }
			if($li[2]){ $d->{'description'} = $li[2]; }
			if($li[3] && $li[3] =~ /<a href="([^\"]+)">/){ $d->{'url'} = $1; }

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

