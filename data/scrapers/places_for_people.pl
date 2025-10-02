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

# If the file exists
if(-e $file){

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	$str =~ s/–/-/g;

	# Build a web scraper
	my $warmspaces = scraper {
		process 'a.WarmHub', "warmspaces[]" => {
			'url' => '@HREF',
			'title' => scraper {
				process 'h1', 'title' => 'TEXT';
			}
		};
	};

	# Build a web scraper for an individual page
	my $placescrape = scraper {
		process 'article.c-article h1', "title" => 'TEXT';
		process 'article.c-article .u-mx-4 p', "p[]" => 'TEXT';
	};

	my $res = $warmspaces->scrape( $str );

	for($j = 0; $j < @{$res->{'warmspaces'}}; $j++){
		$d = {};
		$d->{'title'} = $res->{'warmspaces'}[$j]{'title'}{'title'};
		$url = "https://www.placesforpeople.co.uk".$res->{'warmspaces'}[$j]{'url'};
		$d->{'url'} = $url;


		# Get new page here
		$rfile = "raw/places-for-people-$j.html";
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

		my $place = $placescrape->scrape( $str );
		for($p = 0; $p < @{$place->{'p'}}; $p++){
			$place->{'p'}[$p] =~ s/[\n\r\t]//g;
			if($place->{'p'}[$p] =~ /(Telephone|Email):/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"").$place->{'p'}[$p];
			}elsif($place->{'p'}[$p] =~ /Location: (.*)/){
				$d->{'address'} = $1;
			}elsif($place->{'p'}[$p] =~ /For more info/i){
				if($place->{'p'}[$p] =~ /href="([^\"]+)"/){
					$d->{'url'} = $1;
				}
			}elsif($place->{'p'}[$p] =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/i){
				$d->{'hours'} = parseOpeningHours({'_text'=>$place->{'p'}[$p]});
				if(!defined($d->{'hours'}{'opening'})){
					delete $d->{'hours'};
				}
			}else{
				$d->{'description'} .= ($d->{'description'} ? " ":"").$place->{'p'}[$p];
			}
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
