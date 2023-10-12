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
	
	my $page = scraper {
		process '.paging--search li.paging__item a', 'urls[]' => '@HREF';
	};
	my @urls = @{$page->scrape( $str )->{'urls'}};
	my @entries;

	# Build a web scraper
	my $warmspaces = scraper {
		process '.card.card--contact', "warmspaces[]" => scraper {
			process '.card__heading', 'title' => 'TEXT';
			process 'a.card__link', 'url' => '@HREF';
			process '.nvp__value--contact-address li', 'address[]' => 'HTML';
			process '.nvp__value--contact-telephone', 'contact' => 'TEXT';
		}
	};

	for($u = -1; $u < @urls; $u++){
		if($u >= 0){
			# Get the URL
			$rfile = "raw/lewes_and_eastbournce-".($u+1).".html";
			
			warning("\tGetting details for $u\n");

			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $urls[$u] to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$urls[$u]' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}
		$res = $warmspaces->scrape( $str );
		for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
			$d = $res->{'warmspaces'}[$i];
			if($d->{'address'}){ $d->{'address'} = join(", ",@{$d->{'address'}}); }
			if($d->{'contact'}){ $d->{'contact'} = "Tel: ".$d->{'contact'}; }
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
