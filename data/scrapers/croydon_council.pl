#!/usr/bin/perl

use lib "./";
use utf8;
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
	
#	my %lookup;
#
#	while($str =~ s/<h3>[\n\r\t\s]*<a href="([^\"]+)" rel="bookmark"><span>(.*?)<\/span>[\n\r\t\s]*<\/a>[\n\r\t\s]*<\/h3>[\n\r\t\s]*<div class="field field--name-body field--type-text-with-summary field--label-hidden field__item">(.*?)<\/div>//s){
#		$lookup{$2} = {'url'=>$1,'description'=>3};
#		print "$1 - $2 - $3\n\n";
#	}
	
	print Dumper %lookup;


	if($str =~ /<script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);
		
		for($i = 0; $i < @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}}; $i++){
			$temp = $json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}[$i];
			$d = {};
			$d->{'lat'} = $temp->{'lat'};
			$d->{'lon'} = $temp->{'lon'};
			$d->{'title'} = $temp->{'label'};
			$temp->{'popup'} =~ s/[\n\r]//g;
			if($temp->{'popup'} =~ /<a href="([^\"]*)" rel="bookmark">/){
				$d->{'url'} = "https://www.brighton-hove.gov.uk".$1;
			}

			if($temp->{'popup'} =~ /<div class="field field--name-body field--type-text-with-summary field--label-hidden field__item">(.*?)<\/div>/){
				$desc = $1;
				$desc =~ s/<\/p><p>/ /g;
				$desc =~ s/<[^\>]*>//g;
				$desc =~ s/\s{2,}/ /g;
				$d->{'hours'} = parseOpeningHours({'_text'=>$desc});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
			}
			if($temp->{'popup'} =~ /<address>(.*?)<\/address>/){
				$d->{'address'} = $1;
				$d->{'address'} =~ s/<[^\>]*>//g;
				$d->{'address'} =~ s/(^[\s\t]+|[\s\t]+$)//g;
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

