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
	
	#print $str;
	while($str =~ s/<h4>(.*?)<\/h4>(.*?)<hr ?\/?>//s){
		if($1 ne "<strong>Lancashire warm spaces grant scheme</strong>"){
			$d = { 'title'=>parseText($1) };
			$content = $2;
			$content =~ s/\&ndash;/-/g;
			$content =~ s/\&nbsp;/ /g;
			if($content =~ /<p><strong>Where(\s|\&nbsp;)?:(\s|\&nbsp;)?<\/strong>(.*?)<\/p>/){ $d->{'address'} = parseText($3); }
			if($content =~ /<p><strong>Description(\s|\&nbsp;)?:(\s|\&nbsp;)?<\/strong>(.*?)<\/p>/){ $d->{'description'} = parseText($3); }
			if($content =~ /<p><strong>Phone(\s|\&nbsp;)?:(\s|\&nbsp;)?<\/strong>(.*?)<\/p>/){ $d->{'contact'} .= "Tel: ".parseText($3); }
			if($content =~ /<p><strong>Email(\s|\&nbsp;)?:(\s|\&nbsp;)?<\/strong>(.*?)<\/p>/){ $d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".parseText($3); }
			$hours = "";
			while($content =~ s/<p>(.*?[0-9\:]+(am|pm).*?)<\/p>//){
				$hours .= $1;
			}
			$hours =~ s/<[^\>]+>.*?<\/[^\>]+>//g;
			if($hours){
				$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			}
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

