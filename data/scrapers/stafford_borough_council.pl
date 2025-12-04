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

	$str =~ s/\&nbsp;/ /g;

	@entries = ();

	if($str =~ s/<div class="com">.*?<hr ?\/?>(.*?)<\/div>//s){
		$str = $1;
		while($str =~ s/<h2>([^\<]+)<\/h2>[\n\t\r\s]*<h3>([^\<]*)<\/h3>(.*?)<hr ?\/?>//s){
			$d = {};
			$d->{'title'} = $1;
			$d->{'address'} = $2;			
			$entry = $3;
			$url = "";
			if($entry =~ /<a href="([^\"]+)">/s){ $d->{'url'} = $1; }
			if($entry =~ /<p><strong>Open:<\/strong>(.*?)<\/p>[\n\r\t\s]*<p><strong>Times:<\/strong>(.*?)<\/p>/s){
				$d->{'hours'} = parseOpeningHours({'_text'=>$1."".$2});
			}
			push(@entries,makeJSON($d,1))
		}
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

