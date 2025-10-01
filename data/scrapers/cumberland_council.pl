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

	my $baseurl = "https://www.cumberland.gov.uk";
	my %places;


	if($content =~ /<script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		eval {
			$json = JSON::XS->new->decode($str);
		};
		if($@){ error("\tInvalid output in $file.\n"); $json = {}; }
		@features = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};
		for($f = 0; $f < @features; $f++){
			$d = {};
			if($features[$f]{'lat'}){
				$d->{'lat'} = $features[$f]{'lat'};
			}
			if($features[$f]{'lon'}){
				$d->{'lon'} = $features[$f]{'lon'};
			}
			$features[$f]{'popup'}{'value'} =~ s/\n//g;
#			$features[$f]{'popup'}{'value'} =~ s/[\s\t]+/\s/g;
			if($features[$f]{'popup'}{'value'} =~ /<h3[^\>]*>(.*?)<\/h3>/s){
				$d->{'title'} = $1;
				if($d->{'title'} =~ /href="([^\"]+)"/){
					$d->{'url'} = "https://www.cumberland.gov.uk".$1;
				}
				$d->{'title'} =~ s/<[^\>]*>//g;
				$d->{'title'} =~ s/(^\s+|\s+$)//g;
			}
			if($features[$f]{'popup'}{'value'} =~ /<a href="tel:[0-9]+">([^\<]*)<\/a>/){
				$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Tel: $1";
			}
			if($features[$f]{'popup'}{'value'} =~ /<div [^\>]*field--type-email[^\>]*>(.*?)<\/div>/){
				$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Email: $1";
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

sub trim {
	my $str = $_[0];
	$str =~ s/(^\s|\s$)//g;
	return $str;
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

