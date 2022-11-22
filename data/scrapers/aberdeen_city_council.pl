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

	while($str =~ s/<div[^\>]+data-lat="([^\"]+)" data-lng="([^\"]+)"[^\>]+typeof="Place">(.*?)(<div\s+data-views-row-index)/$4/){

		$entry = $3;

		$d = {'lat'=>$1+0,'lon'=>$2+0};

		if($entry =~ /<h2 class="field-content"><a href="([^\"]+)" hreflang="en">([^\<]+)<\/a><\/h2>/){
			$d->{'title'} = $2;
			$d->{'url'} = "https://www.aberdeencity.gov.uk".$1;
		}
		if($entry =~ /<div class="views-field views-field-field-opening-times">(.*?)<\/div>/){
			$d->{'hours'} = {'_text'=>$1};
			$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
		}
		if($entry =~ /<div class="views-field views-field-field-address">(.*?)<\/div>/){
			$address = $1;
			$address =~ s/\<[^\>]*\>//g;
			$d->{'address'} = $address;
		}

		if($entry =~ /<div class="views-field views-field-field-features">(.*?)<\/div>/){
			$f = $1;
			$f =~ s/\<[^\>]*\>/ /g;
			$f =~ s/ {2,}/, /g;
			$f =~ s/^\, //g;
			$d->{'description'} = "Features: ".$f;
		}

		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

