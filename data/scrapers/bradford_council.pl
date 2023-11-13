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
	
	my $pages = scraper {
		process 'h2.wp-block-heading a', 'url[]' =>  '@href';
	};
	$pages = $pages->scrape( $str );
	
	# Build a web scraper
	my $warmspaces = scraper {
		process '.wpbdp-listing', "warmspace[]" => scraper {
			process '.wpbdp-field-organisation_name', 'title' => 'TEXT';
			process '.wpbdp-field-organisation_name .value a', 'url' => '@HREF';
			process '.wpbdp-field-address', 'address' => 'TEXT';
			process '.wpbdp-field-postcode', 'postcode' => 'TEXT';
			#process '.wpbdp-field-who_is_the_warm_space_contact .value', 'contact' => 'TEXT';
			#process '.wpbdp-field-telephone_number', 'phone' => 'TEXT';
			process '.wpbdp-field-opening_times .value', 'hours' => 'TEXT';
			process '.wpbdp-field-description .value', 'description' => 'TEXT';
			#process '.wpbdp-field-facilitiesamenities .value', 'facilities' => 'TEXT';
		}
	};


	for($p = 0; $p < @{$pages->{'url'}}; $p++){

		$url = $pages->{'url'}[$p];
		

		if($url =~ /.*warm-spaces-directory\/([^\/]*)\/?/){
			$section = $1;
			$rfile = "raw/bradford-council-$section.html";
			warning("\tGetting details for $p = $section (<cyan>$rfile<none>)\n");

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
			$html = join("",@lines);
			
			
			
			$urls = {};

			if($str =~ /var WPBDP_googlemaps_data = \{"map_0":(.*?)\};\n/){
				@locs = @{parseJSON($1)->{'locations'}};
				
				for($l = 0; $l < @locs; $l++){
					$urls->{$locs[$l]{'url'}} = $locs[$l];
				}
			}


			$res = $warmspaces->scrape( $html );
			
			for($i = 0; $i < @{$res->{'warmspace'}}; $i++){
				$d = $res->{'warmspace'}[$i];
				if($d->{'title'}){

					if($d->{'postcode'} && $d->{'address'}){ $d->{'address'} .= ', '.$d->{'postcode'}; }
					$d->{'address'} =~ s/\, +\,/\,/g;
					if($d->{'hours'}){ $d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}}); }
					if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
					
					if($urls->{$d->{'url'}}){
						if($urls->{$d->{'url'}}{'geolocation'} && !$d->{'lat'}){
							$d->{'lat'} = $urls->{$d->{'url'}}{'geolocation'}{'lat'};
							$d->{'lon'} = $urls->{$d->{'url'}}{'geolocation'}{'lng'};
						}
					}
					push(@entries,makeJSON($d,1));
				}
			}
		}
	}


	warning("\tSaved to $file.json\n");
	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}




sub parseJSON {
	my $str = $_[0];
	my ($json);
	# Error check for JS variable
	$str =~ s/[^\{]*var [^\{]+ = //g;
	if(!$str){ $str = "{}"; }
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid output in $file.\n"); $json = {}; }
	
	return $json;
}
