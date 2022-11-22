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
		# Parse all DIVs with the class warmspace and store them into
		# an array 'warmspaces'.  We embed other scrapers for each DIV.

		process 'table tr', "warmspaces[]" => scraper {
#			# And, in each DIV,
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

			if($d->{'td'}[0] =~ /^<p>(.*?)<\/p><p>(.*?)<\/p>/){
					$d->{'address'} = $1;
					$d->{'contact'} = $2;
			}else{
				$d->{'address'} = $d->{'td'}[0];
				if($d->{'address'} =~ s/<p>(.*)<\/p>//){
					$d->{'contact'} = $1;
				}
			}

			# If we have opening hours, parse them
			if($d->{'td'}[1]){
				$d->{'td'}[1] =~ s/ / /g;
				$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'td'}[1]});
			}

			# Remove the <li> entry
			delete $d->{'td'};

#print Dumper $d;

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

