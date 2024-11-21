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

	$str =~ s/[\n\r]/ /g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	while($str =~ s/<div class="service-summary-left col-sm-8 col-xs-12 bem-search-result-item__summary-left">(.*?)(<div class="service-summary-right)//){
		
		$item = $1;
		$d = {};

		if($item =~ /<a[^\>]*href="([^\"]+)" itemprop="url">([^\<]+)<\/a>/){
			$d->{'title'} = $2;
			$d->{'url'} = ($1 =~ /^\// ? "https://livewellservices.cheshireeast.gov.uk":"").$1;
		}
		if($item =~ /<meta itemprop="latitude" content="([^\"]+)" \/>/){ $d->{'lat'} = $1; }
		if($item =~ /<meta itemprop="longitude" content="([^\"]+)" \/>/){ $d->{'lon'} = $1; }
		if($item =~ /<div class="bem-search-result-item__contact">(.*?)<\/div>/){ $d->{'contact'} = parseText($1); $d->{'contact'} =~ s/Telephone:/Tel:/g }
		if($item =~ /<p class="service-location bem-search-result-item__location">(.*?)<\/p>/){ $d->{'address'} = parseText($1); }
		
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

