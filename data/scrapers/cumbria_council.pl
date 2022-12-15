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
	$content = $str;

	my %lookup;

	if($str =~ /<script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);
		
		#$n = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};
		
		for($i = 0; $i < @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}}; $i++){
			$temp = $json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}[$i];
			
			$lookup{$temp->{'label'}} = {'lat'=>$temp->{'lat'},'lon'=>$temp->{'lon'}};
			$temp->{'popup'} =~ s/[\n\r]//g;
			if($temp->{'popup'} =~ /<a href="([^\"]*)" rel="bookmark">/){
				$lookup{$temp->{'label'}}{'url'} = $1;
			}
		}
	}

	# Build a web scraper
	my $warmspaces = scraper {
		process 'div[class="views-row"] article', "warmspaces[]" => scraper {
			process 'h2 > a', 'url' => '@HREF';
			process 'h2', 'title' => 'TEXT';
			process 'div[class="field field--name-field-what-can-people-expect field--type-string field--label-hidden field__items"]', 'description' => 'TEXT';
			process 'div[class="field field--name-field-contact-phone field--type-telephone field--label-hidden field__item"]', 'tel' => 'TEXT';
			process 'div[class="field field--name-localgov-directory-email field--type-email field--label-hidden field__item"]', 'email' => 'TEXT';
		};
	};
	my $res = $warmspaces->scrape( $content );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		if($d->{'tel'}){ $d->{'contact'} .= ($d->{'contact'} ? "; " : "").'Tel: '.$d->{'tel'}; }
		if($d->{'email'}){ $d->{'contact'} .= ($d->{'contact'} ? "; " : "").'Email: '.$d->{'email'}; }
		delete $d->{'tel'};
		delete $d->{'email'};
		
		$d->{'title'} = trim($d->{'title'});
		
		if($lookup{$d->{'title'}}){
			$d->{'lat'} = $lookup{$d->{'title'}}{'lat'};
			$d->{'lon'} = $lookup{$d->{'title'}}{'lon'};
			"https://new.cumbria.gov.uk"
		}
		if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://new.cumbria.gov.uk".$d->{'url'}; }

		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

sub trim {
	my $str = $_[0];
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
