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

	while($str =~ s/<h3 class="disclosurestart">(.*?)<\/h3>(.*?)<p class="disclosureend">&nbsp;<\/p>//){
		$d = {'title'=>$1};
		$entry = $2;
		while($entry =~ s/<p>(.*?)<\/p>//){
			$p = parseText($1);
			if($p =~ /Address: (.*)/){ $d->{'address'} = $1; }
			if($p =~ /Telephone: (.*)/){ $d->{'contact'} = $1; }
			if($p =~ /Facilities: (.*)/){ $d->{'description'} = $1; }
			if($p =~ /Opening days and times: (.*)/){ $d->{'hours'} = parseOpeningHours({'_text'=>$1}); }
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

