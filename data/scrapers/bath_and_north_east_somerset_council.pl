#!/usr/bin/perl

use lib "./";
use utf8;
use Data::Dumper;
use Web::Scraper;
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
	
	# Build a web scraper
	my $warmspaces = scraper {
		process 'div.warm-places', "warmspaces[]" => scraper {
			process '.views-field-title h2', 'title' => 'TEXT';
			process '.views-field-title a', 'url' => '@HREF';
			process '.views-field-localgov-directory-address', 'address' => 'TEXT';
		}
	};

	$total = 0;
	$page = 0;
	if($str =~ /of ([0-9]+) warm spaces/){
		$total = $1;
	}

	while(@entries < $total && $page < 10){
		
		if($str eq ""){
			$page++;
			$url = "https://livewell.bathnes.gov.uk/warm-spaces-directory?page=$page";
			$rfile = $file;
			$rfile =~ s/\.html/-$page.html/;
		
			warning("\tGetting details for page <yellow>$page<none> from <cyan>$url<none>\n");

			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $url to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$url' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}

		# Trim before and after
		$str =~ s/<!--.*?-->//sg;
		$str =~ s/.*<main class="govuk-main-wrapper" id="main">//gs;
		$str =~ s/<\/main>.*//sg;


		my $res = $warmspaces->scrape( $str );

		$n = @{$res->{'warmspaces'}};
		warning("\tMatched $n warmspaces on page.\n");

		for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
			$d = $res->{'warmspaces'}[$i];
			$d->{'address'} = trim($d->{'address'});
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://livewell.bathnes.gov.uk".$d->{'url'}; }

			# Store the entry as JSON
			push(@entries,makeJSON($d,1));
		}
		$str = "";
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}


sub trim {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>/, /g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/ , /, /g;
	$str =~ s/\, ?\, ?/, /g;
	$str =~ s/\, ?\, ?/, /g;
	$str =~ s/(^\, ?\, ?|^\, ?|\, ?$|\, ?\,$)//g;
	return $str;
}