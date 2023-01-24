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

	$str =~ s/[\n\r]//g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;


	if($str =~ /<h2><a id="Warm_welcome_community_spaces" .*?<\/h2>(.*?)<h2>/){
		$str = $1;

		while($str =~ s/<li>(.*?)<\/li>//){
			$li = $1;
			$d = {};
			if($li =~ /<a href="([^\"]*)">([^\<]+)<\/a>/){
				$d->{'title'} = $2;
				$d->{'url'} = $1;
			}
			if($li =~ /<br \/>[\n\t\s]*(.*?)[\n\t\s]*<br \/>/){
				$d->{'address'} = $1;
			}

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

