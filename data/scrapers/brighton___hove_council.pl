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


	# Build a web scraper
	my $pages = scraper {
		process 'li', "pp[]" => scraper {
			process 'a', 'url' => '@HREF';
		}
	};

	my $warmspaces = scraper {
		process '.data-list article', "warmspace[]" => scraper {
			process 'h2', 'title' => 'TEXT';
			process '.field--name-postal-address', 'address' => 'TEXT';
			process 'a.inline-flex', 'url' => '@HREF';
			process '.field--name-localgov-directory-email a', 'email' => '@HREF';
			process '.field--name-localgov-directory-phone', 'tel' => 'TEXT';
			process '.field--name-body', 'description' => 'TEXT';
		}
	};

	$pp = {};

	if($str =~ /<h3[^\>]*>Pagination<\/h3>.*?(<ul[^\>]+>.*?<\/ul>)/s){
		$li = $1;
		while($li =~ s/<li[^\>]+>.*?<a[^\>]+href="([^\"]+)".*?<\/li>//s){
			$url = $1;
			if($url =~ /page=([0-9]+)/){
				$pp->{$1} = "https://www.brighton-hove.gov.uk/cost-living-support/directories/warm-welcome-directory-indoor-activities-and-places-go".$url;
			}
		}
	}

	foreach $p (sort(keys(%{$pp}))){
		if($p > 0){
			$rfile = "raw/brighton___hove_council-$p.html";
			warning("\tGetting details for $p (<cyan>$rfile<none>)\n");
			$url = $pp->{$p};
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving <green>$purl<none> to <cyan>$rfile<none>\n");
				# Download the section
				`curl -s --insecure --compressed -o $rfile "$url"`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);			
		}
		
		$res = $warmspaces->scrape( $str );

		@results = @{$res->{'warmspace'}};

		for($i = 0; $i < @results; $i++){
			$d = {};
			$d->{'title'} = $results[$i]->{'title'};
			$d->{'url'} = $results[$i]->{'url'};
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.brighton-hove.gov.uk".$d->{'url'}; }
			$d->{'description'} = $results[$i]->{'description'};
			$d->{'address'} = $results[$i]->{'address'};
			if($results[$i]->{'tel'}){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$results[$i]->{'tel'};
			}
			if($results[$i]->{'email'}){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$results[$i]->{'email'};
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

