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
		process 'div[class="widget_content byEditor by_editor editor"] table tr', "warmspaces[]" => scraper {
			process "td", "td[]" => 'HTML';
			process "td:first-child p:first-child strong", "title" => 'TEXT';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){
		$place = $res->{'warmspaces'}[$i];
		
		$d->{'title'} = $place->{'title'};
		$d->{'title'} =~ s/ \([^\)]+\)$//;
		$place->{'td'}[0] =~ s/^<p>(.*?)<\/p>//;
		$d->{'address'} = parseText($place->{'td'}[0]);
		$place->{'td'}[3] =~ s/[\(\)]//g;
		$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($place->{'td'}[1])});
		$place->{'td'}[3] =~ s/<\/li>/\, /g;
		$d->{'description'} = "Facilities: ".parseText($place->{'td'}[3]);
		$d->{'description'} =~ s/[\s]\,/\,/g;
		$d->{'description'} =~ s/\,$//g;

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
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}