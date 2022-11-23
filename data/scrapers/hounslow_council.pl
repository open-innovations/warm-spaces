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
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$d->{'title'} = parseText($d->{'td'}[0]);
		$d->{'address'} = parseText($d->{'td'}[1]);
		$d->{'td'}[3] =~ s/[\(\)]//g;
		$d->{'hours'} = parseOpeningHours({'_text'=>parseText($d->{'td'}[3])});
		$d->{'td'}[4] =~ s/<\/p>/\, /g;
		$d->{'description'} = "Facilities: ".parseText($d->{'td'}[4]);
		$d->{'description'} =~ s/[\s]\,/\,/g;
		$d->{'description'} =~ s/\,$//g;
		
		# Remove the <td> entry
		delete $d->{'td'};

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

