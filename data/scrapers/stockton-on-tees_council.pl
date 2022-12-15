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
		process 'div[class="event-search"] div[class="service-results__item"]', "warmspaces[]" => scraper {
			process 'div[class="service-results__title"] > a', 'url' => '@HREF';
			process 'div[class="service-results__title"] > a', 'title' => 'TEXT';
			process 'div[class="service-results__summary"]', 'description' => 'TEXT';
			process 'li[class="nvp nvp--service nvp--service-location"] span[class="nvp__value"]', 'address' => 'TEXT';
			process 'li[class="nvp nvp--service nvp--service-contact"] span[class="nvp__value"]', 'contact' => 'TEXT';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){

		$d = $res->{'warmspaces'}[$i];
		$d->{'address'} = trimHTML($d->{'address'});
		$d->{'description'} = trimHTML($d->{'description'});


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



sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}