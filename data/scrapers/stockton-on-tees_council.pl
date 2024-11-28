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
	
	
	# Build a web scraper
	my $warmspaces = scraper {
		process 'div.service-results__item', "warmspaces[]" => scraper {
			process 'a.service__results--heading', 'title' => 'TEXT';
			process 'a.service__results--heading', 'url' => '@HREF';
			process 'div.service-results__summary', 'description' => 'TEXT';
			process '.nvp--service-location .nvp__value', 'address' => 'HTML';
			process '.nvp--service-contact .nvp__value', 'contact' => 'TEXT';
		};
	};
	

	# Get list from this page
	$next = "placeholder";
	$n = 0;
	$p = 0;
	%pins;
	while($next){
		if($n>0){
			# Get new page here
			$rfile = "raw/stockton-on-tees_council-page$n.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $next to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$next' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}

		if($str =~ /"paging__link paging__link--next"[^\<]* href="([^\"]+)"/s){
			$next = $1;
		}else{
			$next = "";
		}


		while($str =~ s/pins.push\(\{.*?position: \[([^\,]+),([^\]]+)\].*?key: ([0-9]+)//s){
			$id = $3;
			$pins{$id} = {};
			$pins{$id}{'lat'} = $1;
			$pins{$id}{'lon'} = $2;
			$url = "https://www.stockton.gov.uk/community-spaces-directory?articleid=$id&ajax=true";
			$rfile = "raw/stockton-on-tees_council-pin$id.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $next to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$url' -o $rfile -s --insecure -H 'Accept: application/json' -H 'Content-type: application/json'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$txt = join("",@lines);
			$pins{$id}{'result'} = JSON::XS->new->decode($txt);
			$p++;
		}

		my $res = $warmspaces->scrape( $str );

		for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
			$d = $res->{'warmspaces'}[$i];

			$d->{'address'} = trimHTML($d->{'address'});
			$d->{'title'} = trimHTML($d->{'title'});
			if($d->{'contact'}){ $d->{'contact'} = trimHTML($d->{'contact'}); }
			foreach $id (keys(%pins)){
				if($d->{'title'} eq $pins{$id}{'result'}{'name'}){
					$d->{'lat'} = $pins{$id}{'lat'};
					$d->{'lon'} = $pins{$id}{'lon'};
					if($pins{$id}{'result'}{'link'}){ $d->{'url'} = $pins{$id}{'result'}{'link'}; }
					if($pins{$id}{'result'}{'summary'}){ $d->{'description'} = $pins{$id}{'result'}{'summary'}; }
				}
			}
			push(@entries,makeJSON($d,1));
		}
		$n++;
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
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}