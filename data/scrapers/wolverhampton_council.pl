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

	@entries;

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	$str =~ s/[\n\r]//g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	$str =~ s/.*<div class="field field--name-field-title field--type-string field--label-hidden field__item">Warm Spaces Venues<\/div>//g;
	$str =~ s/Warm Spaces Shuttle Service.*$//g;

	# We have to use really simple regex parsing because the structure is linear
	while($str =~ s/<h3>(.*?)<\/h3><p>(.*?)<\/p>//){
		$d = {'title'=> $1 };
		$temp = $2;
		if($temp =~ /<strong>Address: <\/strong>(.*?)<br/){ $d->{'address'} = $1; }
		if($temp =~ /<strong>Opening Times: ?<\/strong>(.*)/){
			$d->{'hours'} = parseOpeningHours({'_text'=>$1});
		}
		push(@entries,makeJSON($d));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

