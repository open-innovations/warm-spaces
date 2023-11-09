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


	# Build a web scraper
	my $warmspaces = scraper {
		process 'article.gd_place_tags-warm-spaces, article.gd_placecategory-warm-spaces1', "warmspaces[]" => scraper {
			process 'h1', 'title' => 'TEXT';
			process 'a', 'url' => '@HREF';
			process '*', 'id' => '@ID';
		}
	};
	
	# Build a web scraper
	my $pp = scraper {
		process 'a.page-link', "pages[]" => '@HREF';
	};
	my $res = $pp->scrape( $str );
	my $endpage = 1;
	for($i = 0; $i < @{$res->{'pages'}}; $i++){
		if($res->{'pages'}[$i] =~ /page\/([0-9]+)\//){
			if($1 > $endpage){ $endpage = $1; }
		}
	}


	for($i = 1; $i <= $endpage; $i++){

		$url = $res->{'pages'}[0];
		$url =~ s/page\/([0-9]+)\//page\/$i/;
		$rfile = "raw/essex_map_page_$i.html";
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
		
		$warm = $warmspaces->scrape( $str );
		
		for($j = 0; $j < @{$warm->{'warmspaces'}}; $j++){
			$d = $warm->{'warmspaces'}[$j];
			$d->{'id'} =~ s/post-//g;
			if($d->{'url'} =~ /https:\/\/www.essexmap.co.uk/){

				$url = $d->{'url'};
				$rfile = "raw/essex_map_post_$d->{'id'}.html";
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

				if($str =~ /<script type="application\/ld\+json">(.*?)<\/script>/){
					$json = $1;
					if(!$json){ $json = "{}"; }
					eval {
						$json = JSON::XS->new->decode($json);
					};
					if($@){ warning("\tInvalid JSON.\n".$json); }
					if(ref($json) eq "ARRAY"){
						$json = {'array'=>\@{$json}};
					}
					if($json->{'geo'}){
						$d->{'lat'} = $json->{'geo'}{'latitude'};
						$d->{'lon'} = $json->{'geo'}{'longitude'};
					}
					if($json->{'address'} && $json->{'address'}{'@type'} eq "PostalAddress"){
						$d->{'address'} = $json->{'address'}{'streetAddress'};
						#if($json->{'address'}{'addressLocality'}){ $d->{'address'} .= ($d->{'address'} ? ", ":"").$json->{'address'}{'addressLocality'}; }
						#if($json->{'address'}{'addressRegion'}){ $d->{'address'} .= ($d->{'address'} ? ", ":"").$json->{'address'}{'addressRegion'}; }
						#if($json->{'address'}{'postalCode'}){ $d->{'address'} .= ($d->{'address'} ? ", ":"").$json->{'address'}{'postalCode'}; }
					}
					if($json->{'openingHours'}){
						$d->{'hours'} = parseOpeningHours({'_text'=>join("; ",@{$json->{'openingHours'}})});
						if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
					}
					if($json->{'description'}){
						$d->{'description'} = $json->{'description'};
					}
					delete $d->{'id'};
				}
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
