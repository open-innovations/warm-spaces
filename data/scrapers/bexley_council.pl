#!/usr/bin/perl

use lib "./";
use utf8;
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

	if($str =~ /<h2 class="page-title">.*<article[^\>]*>(.*)<\/article>/s){
		$str = $1;

		while($str =~ s/<h3>(.*?)<\/h3>(.*?)<h3>/<h3>/s){
			$title = $1;
			$content = $2;
			$d = {};
			if($title =~ /^([^\,]*)\,? ?(.*)$/){
				$d->{'title'} = $1;
				if($2){ $d->{'address'} = $2; }
			}
			$content =~ s/\n//g;
			$d->{'description'} = $content;

			if($content =~ /<a href="([^\"]+)"/s){
				$d->{'url'} = $1;
			}

			$d->{'hours'} = parseOpeningHours({'_text'=>$content});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }

			if($d->{'address'}){
				push(@entries,makeJSON($d,1));
			}
		}

	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

