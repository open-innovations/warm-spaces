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
	@pages;
	
	# Get pages
	while($str =~ s/<a [^\>]*class="number bem-pagination__link" href="([^\"]+)">([0-9]+)<//){
		if($1 ne "#"){
			$pages[$2-1] = "https://directory.hertfordshire.gov.uk".$1;
		}else{
			$pages[$2-1] = "";
		}
	}

	for($p = 0; $p < @pages; $p++){
		# Fix links
		$pages[$p] =~ s/\&amp;/\&/g;

		if($pages[$p]){
			# Get new page here
			$rfile = "raw/hertfordshire-council-$p.html";
			$url = $pages[$p];
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving page $n (<green>$url<none>) to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$url' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1' -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0" -H "Accept-Language: en-GB,en;q=0.5" -H "Accept-Encoding: gzip, deflate"`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
			$str =~ s/\&nbsp\;/ /g;
		}


		while($str =~ s/<div class="bem-search-result-item[^>]*>(.*?)<\/div>[\n\s\r\t]*(<div class="bem-search-result-item|<nav)/$2/s){
			$content = $1;
			$d = {};
			if($content =~ s/<a href="([^\"]+)" class="bem-search-result-item__contact-item-link">//s){ $d->{'url'} = $1; }
			if($content =~ s/<a class="service-name[^\>]*href="([^\"]+)"[^\>]*>(.*?)<\/a>//sg){ $d->{'url'} = ($d->{'url'}||$1); $d->{'title'} = $2; }
			if($content =~ s/<p class="bem-search-result-item__summary">(.*?)<\/p>//sg){ $d->{'description'} = $1; }
			if($content =~ s/<meta itemprop="latitude" content="([^\"]+)" \/>//sg){ $d->{'lat'} = $1; }
			if($content =~ s/<meta itemprop="longitude" content="([^\"]+)" \/>//sg){ $d->{'lon'} = $1; }
			if($content =~ s/<span itemprop="streetAddress">(.*?)<\/span>//sg){ $d->{'address'} = $1; }
			if($content =~ s/<span itemprop="postalCode">(.*?)<\/span>//sg){ $d->{'address'} .= " ".$1; }
			if($content =~ s/<div class="bem-search-result-item__contact">(.*?)<\/div>//sg){ $d->{'contact'} = trimHTML($1); }

			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://directory.hertfordshire.gov.uk".$d->{'url'}; }

			if($d->{'title'}){
				# Store the entry as JSON
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
