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


	# Build a web scraper to find the HTML entries
	my $warmspace = scraper {
		process '.field--name-postal-address .address', "address" => 'HTML';
		process '.field--name-localgov-directory-opening-times tr td', "td[]" => 'TEXT';
		process '.field--name-localgov-directory-phone .field__item a', 'tel' => 'TEXT';
		process '.field--name-localgov-directory-website .field__item a', 'url' => '@HREF';
	};

	if($str =~ /<script type=\"application\/json\" data-drupal-selector=\"drupal-settings-json\">(.*?)<\/script>/){
		$txt = $1;
		if(!$txt){ $txt = "{}"; }
		$json = JSON::XS->new->decode($txt);
		@features = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};
	}
	for($i = 0; $i < @features; $i++){
		$d = {
			'title'=>$features[$i]{'title'},
			'lat'=>$features[$i]{'lat'},
			'lon'=>$features[$i]{'lon'}
		};
		if($features[$i]{'popup'}{'value'} =~ /<div class="field field--name-body field--type-text-with-summary field--label-hidden field__item">(.*?)<\/div>/){
			$d->{'description'} = trimHTML($1);
		}
		if($features[$i]{'popup'}{'value'} =~ /href="([^\"]+)"/){
			$d->{'url'} = $1;
			if($d->{'url'} =~ /^\//){
				$d->{'url'} = "https://new.haringey.gov.uk".$d->{'url'};

				# Get page
				$rfile = "raw/haringey_council-p$i.html";
				# Keep cached copy of individual URL
				$age = getFileAge($rfile);
				if($age >= 86400 || -s $rfile == 0){
					warning("\tSaving $next to <cyan>$rfile<none>\n");
					# For each entry we now need to get the sub page to find the location information
					`curl '$d->{'url'}' -o $rfile -s --insecure`;
				}
				open(FILE,"<:utf8",$rfile);
				@lines = <FILE>;
				close(FILE);
				$str = join("",@lines);
				$res = $warmspace->scrape($str);
				$res->{'address'} =~ s/<\/?span[^\>]*>//g;
				$res->{'address'} =~ s/<br ?\/?>/, /g;
				$d->{'address'} = $res->{'address'};
				
				
				$d->{'url'} = $res->{'url'};
				
				if($res->{'tel'}){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: $res->{'tel'}";
				}

				$hours = "";
				for($j = 0; $j < @{$res->{'td'}}; $j+=2){
					$hours .= ($hours ? "; ":"")."$res->{'td'}[$j] $res->{'td'}[$j+1]";
				}
				if($hours){
					$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
				}
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



sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}

