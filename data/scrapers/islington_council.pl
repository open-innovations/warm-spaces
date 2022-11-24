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
		process 'table[class="responsive"] tbody tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$td = @{$d->{'td'}};
		if($td > 0){
			$d->{'td'}[0] =~ s/[\n\r]//g;

			if($d->{'td'}[0] =~ /<a[^\>]*href="([^\"]+)"[^\>]*>(.*?)<\/a>/){
				$d->{'url'} = $1;
				$d->{'title'} = $2;
			}else{
				$d->{'title'} = parseText($d->{'td'}[0]);
			}

			$d->{'td'}[1] =~ s/[^A-Za-z0-9 ]//g;
			if($d->{'td'}[1]){
				$d->{'address'} = $d->{'td'}[1];
			}

			# Remove the <li> entry
			delete $d->{'td'};

			# Store the entry as JSON
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

