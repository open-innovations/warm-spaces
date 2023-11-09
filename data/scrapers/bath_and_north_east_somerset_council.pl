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
	
	$str =~ s/<meta[^\>]*>//g;
	

	# Build a web scraper
	my $warmspaces = scraper {
		process 'div.geolocation-location', "warmspaces[]" => scraper {
			process 'h2', 'title' => 'TEXT';
			process '.views-field-title a', 'url' => '@HREF';
			process '.views-field-localgov-directory-address', 'address' => 'HTML';
			process '*', 'lat' => '@data-lat';
			process '*', 'lon' => '@data-lng';
		}
	};
	my $res = $warmspaces->scrape( $str );

	$n = @{$res->{'warmspaces'}};
	warning("\tMatched $n warmspaces on page.\n");

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$d->{'address'} = trim($d->{'address'});
		if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://livewell.bathnes.gov.uk".$d->{'url'}; }

		# Store the entry as JSON
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>/, /g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/ , /, /g;
	$str =~ s/\, ?\, ?/, /g;
	$str =~ s/\, ?\, ?/, /g;
	$str =~ s/(^\, ?\, ?|^\, ?|\, ?$|\, ?\,$)//g;
	return $str;
}