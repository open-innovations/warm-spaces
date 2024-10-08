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


	# Build a web scraper for directory index
	my $pages = scraper {
		process 'ul.item-list--az .item-list__item a', "pages[]" => '@HREF';
	};
	my $rtn = $pages->scrape( $str );

	@entries;

	# Build a web scraper for individual pages
	my $warmspaces = scraper {
		process 'nav.nav--categories .item-list__item', "warmspaces[]" => scraper {
			process '.item-list__link', 'url' => '@HREF';
			process '.item-list__link', 'title' => 'TEXT';
		}
	};

	for($p = 0; $p < @{$rtn->{'pages'}}; $p++){
		if($p == 0){
			# We alredy have the first page
		}else{
			# Get the page
			$url = "https://www.centralbedfordshire.gov.uk".$rtn->{'pages'}[$p];
			if($rtn->{'pages'}[$p] =~ /a_to_z\/([A-Z])/){
				$rfile = "raw/central_bedfordshire_council-$1.html";
			}else{
				$rfile = "raw/central_bedfordshire_council-$p.html";
			}
			
			$age = 100000;
			if(-e $rfile){
				$epoch_timestamp = (stat($rfile))[9];
				$now = time;
				$age = ($now-$epoch_timestamp);
			}

			# Keep cached copy of individual URL
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $url to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$url' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}

			# Read in the page
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}

		$res = $warmspaces->scrape( $str );

		for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
			
			$d = $res->{'warmspaces'}[$i];
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.centralbedfordshire.gov.uk".$d->{'url'}; }

			$d->{'url'} =~ /directory_record\/([^\/]*)\//;
			$record = $1;
			$rfile = "raw/central-bedfordshire-$record.html";

			
			# Keep cached copy of individual URL
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $d->{'url'} to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}

			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$html = join("",@lines);

			while($html =~ s/<dt[^\>]*>(.*?)<\/dt>[\n\r\t\s]+<dd[^>]*>(.*?)<\/dd>//s){
				$key = $1;
				$value = $2;

				if($key =~ /Street/is){
					$d->{'address'} .= trimHTML($value);
				}elsif($key =~ /Town or village/is){
					$d->{'address'} .= ($d->{'address'} ? ", ":"").trimHTML($value);
				}elsif($key =~ /Postcode/is){
					$d->{'address'} .= ($d->{'address'} ? ", ":"").trimHTML($value);
				}elsif($key =~ /When is it open\?/is){
					$d->{'hours'} = trimHTML($value);
				}elsif($key =~ /Telephone number/is){
					$d->{'contact'} = "Tel: ".trimHTML($value);
				}elsif($key =~ /Website or social media link/is && $value =~ /href="([^\"]+)"/){
					$d->{'url'} = $1;
				}elsif($key =~ /What is available?/is){
					$d->{'description'} .= trimHTML($value);
				}elsif($key =~ /Facilities/is){
					$d->{'description'} .= ($d->{'description'} ? " Facilities: ":"").trimHTML($value);
				}
			}
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }

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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}