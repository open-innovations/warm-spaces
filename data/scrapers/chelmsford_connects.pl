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

	my $pagefinder = scraper {
		process 'ul.pagination li a', "pages[]" => '@HREF';
	};
	# Build a web scraper
	my $warmspaces = scraper {
		process '.search-result', "warmspaces[]" => scraper {
			process 'h3', 'title' => 'TEXT';
			process 'h3 a', 'url' => '@HREF';
			process '.description', 'description' => 'TEXT';
		}
	};

	my $pp = $pagefinder->scrape( $str );

	for($p = 0; $p < @{$pp->{'pages'}}; $p++){
		if($p == 0){
			# Current page
		}else{
			$url = $pp->{'pages'}[$p];
			$rfile = "raw/chelmsford_connects_page_$p.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving <green>$url<none> to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$url' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}

		push(@warm,@{$warmspaces->scrape( $str )->{'warmspaces'}});


	}
	
	for($i = 0; $i < @warm; $i++){
		if($warm[$i]{'url'} =~ /\/([0-9]+)$/){
			$id = $1;


			$rfile = "raw/chelmsford_connects_$id.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving <green>$warm[$i]{'url'}<none> to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$warm[$i]{'url'}' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			
			$html = join("",@lines);
			if($html =~ /<h2 class="first-heading">What is this service\?<\/h2>.*?<p>(.*?)<\/p>/){
				$warm[$i]{'description'} = $1;
			}
			if($html =~ /<h2>Where can I access it\?<\/h2>.*?<p>(.*?)<\/p>/s){
				$warm[$i]{'address'} = $1;
				$warm[$i]{'address'} =~ s/([\s\t\n\r])[\s\t\n\r]+/$1/sg;
				$warm[$i]{'address'} =~ s/[\n\r]/ /g;
				$warm[$i]{'address'} =~ s/<br ?\/>/, /sg;
				$warm[$i]{'address'} = trimHTML($warm[$i]{'address'});
			}
			if($html =~ /https:\/\/www.google.com\/maps\/search\/\?api=1\&query=([0-9\.]+),([0-9\.\-]+)/){
				$warm[$i]{'lat'} = $1;
				$warm[$i]{'lon'} = $2;
			}
			
			if($warm[$i]{'description'}){
				$warm[$i]{'hours'} = parseOpeningHours({'_text'=>$warm[$i]{'description'}});
				if(!$warm[$i]{'hours'}{'opening'}){ delete $warm[$i]{'hours'}{'opening'}; }
			}
			push(@entries,makeJSON($warm[$i],1));
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}