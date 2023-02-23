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
	my $warmspaces = scraper {
		process '.listing-details', "warmspace" => scraper {
			process '.wpbdp-field-address', 'address' => 'TEXT';
			process '.wpbdp-field-postcode', 'postcode' => 'TEXT';
			process '.wpbdp-field-who_is_the_warm_space_contact .value', 'contact' => 'TEXT';
			process '.wpbdp-field-telephone_number', 'phone' => 'TEXT';
			process '.wpbdp-field-opening_times .value', 'hours' => 'TEXT';
			process '.wpbdp-field-description .value', 'description' => 'TEXT';
			process '.wpbdp-field-facilitiesamenities .value', 'facilities' => 'TEXT';
		}
	};

	if($str =~ /var WPBDP_googlemaps_data = (.*);\n/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);	

		for($i = 0; $i < @{$json->{'map_0'}{'locations'}}; $i++){
			$d = $json->{'map_0'}{'locations'}[$i];
			if($d->{'geolocation'}){
				$d->{'lat'} = $d->{'geolocation'}{'lat'};
				$d->{'lon'} = $d->{'geolocation'}{'lng'};
			}
			delete $d->{'geolocation'};
			delete $d->{'content'};
			

			if($d->{'url'} =~ /costoflivingbradford/){
						
				$d->{'url'} =~ /warm-spaces-directory-old\/([^\/]*)\//;
				$record = $1;
				$rfile = "raw/bradford-$record.html";
				
				warning("\tGetting details for $i = $record\n");

				$age = getFileAge($rfile);
				# Keep cached copy of individual URL
				if($age >= 86400 || -s $rfile == 0){
					warning("\tSaving $d->{'url'} to <cyan>$rfile<none>\n");
					# For each entry we now need to get the sub page to find the location information
					`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate' -H 'Upgrade-Insecure-Requests: 1'`;
				}
				open(FILE,"<:utf8",$rfile);
				@lines = <FILE>;
				close(FILE);
				$html = join("",@lines);
				
				my $res = $warmspaces->scrape( $html );
				if($res->{'warmspace'}{'address'} && $d->{'address'}){
					$d->{'address'} = $res->{'warmspace'}{'address'}.", ".$d->{'address'};
				}
				if($res->{'warmspace'}{'contact'}){ $d->{'contact'} = $res->{'warmspace'}{'contact'}; }
				if($res->{'warmspace'}{'phone'}){ $d->{'contact'} .= ($d->{'contact'} ? ", ":"")."Tel: $res->{'warmspace'}{'phone'}"; }

				if($res->{'warmspace'}{'description'}){ $d->{'description'} = $res->{'warmspace'}{'description'}; }
				if($res->{'warmspace'}{'facilities'}){ $d->{'description'} .= ($d->{'description'} ? ". ":"")."Facilities: $res->{'warmspace'}{'facilities'}"; }
				
				if($res->{'warmspace'}{'hours'}){ $d->{'hours'} = parseOpeningHours({'_text'=>$res->{'warmspace'}{'hours'}}); }
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }

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

