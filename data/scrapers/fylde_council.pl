#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
use Web::Scraper;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';

# Get the file to process
$file = $ARGV[0];

# Hard-coded postcodes
$postcodes = {
	'Hope Church'=>'FY8 5AA',
	'St John’s Church'=>'FY8 5EX',
	'St Cuthbert’s Church'=>'FY8 5QL',
	'Kirkham Community Centre'=>'PR4 2AN',
	'Kirkham Library'=>'PR4 2HD',
	'Fairhaven Methodist Church'=>'FY8 1BZ',
	'Wesley’s Warm Spaces at Church Road Methodist Church Community Hub'=>'FY8 3NQ',
	'St Annes Library'=>'FY8 1NR'
};

# If the file exists
if(-e $file){

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	$str =~ s/–/-/g;

	if($str =~ /<div [^\>]*class="wpb_text_column wpb_content_element"[^\>]*>(.*?)<\/div>/s){
		$str = $1;
		while($str =~ s/<h3>(.*?)<\/h3>.*?<ul>(.*?)<\/ul>//s){
			$d = {};
			$title = $1;
			@li = split(/<\/li>/,$2);

			if($title =~ /([^\,]+)\, (.*)/){
				$d->{'title'} = $1;
				$d->{'address'} = $2;
			}else{
				$d->{'title'} = $title;
			}
			# If we don't seem to have a postcode we see if we've hardcoded one
			if($d->{'address'} !~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/ && $postcodes->{$d->{'title'}}){
				$d->{'address'} .= ($d->{'address'} ? ", ":"").$postcodes->{$d->{'title'}};
			}
			# Fix
			$d->{'address'} =~ s/PR4 1 XQ/PR4 1XQ/;

			$hours = "";
			for($i = 0; $i < @li; $i++){
				if($li[$i] =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday): ([^\<]*)/){
					$times = $1.": ".$2;
					# Fix for spaces before am/pm
					$times =~ s/ (pm|am)/$1/g;
					if($times !~ /Closed/i){
						$hours .= ($hours ? "; ":"").$times;
					}
				}
			}
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
