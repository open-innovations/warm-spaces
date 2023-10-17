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
		process 'div[class="table-container"] table > tbody > tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){

		$d = $res->{'warmspaces'}[$i];

		$d->{'td'}[0] =~ s/<\/?p>//g;
		$d->{'td'}[0] =~ s/^(.*?)<br \/> ?//g;
		$d->{'title'} = $1;
		$d->{'address'} = $d->{'td'}[0];
		$d->{'address'} =~ s/<br ?\/?> ?/, /g;

		$d->{'hours'} = parseOpeningHours({'_text'=>parseText($d->{'td'}[2])});
		if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		$d->{'contact'} = "Tel: ".parseText($d->{'td'}[1]);

		# Remove the <li> entry
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

