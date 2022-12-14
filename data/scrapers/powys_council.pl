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
		process 'div[class="directory-entry"]', "warmspaces[]" => scraper {
			process 'a', 'url' => '@HREF';
			process 'h3', 'title' => 'TEXT';
			process 'p[class="hasicon icon--address"]', 'address' => 'TEXT';
			process 'p[class="hasicon icon--facility"]', 'p[]' => 'TEXT';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		
		$d->{'address'} =~ s/Address: ?//g;
		$d->{'description'} = join("; ",@{$d->{'p'}});
		delete $d->{'p'};

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

