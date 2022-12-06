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
		process '#warmspaces-directory .warmspace', "warmspaces[]" => scraper {
			process 'h3', 'title' => 'HTML';
			process 'p', 'p' => 'HTML';
			process 'li', 'li[]' => 'HTML';
			process 'span[class="loc"]', 'loc' => 'TEXT';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$li = @{$d->{'li'}};
		$d->{'description'} = $d->{'p'};
		delete $d->{'p'};
		@coords = split(/,/,$d->{'loc'});
		$d->{'lat'} = $coords[0]+0;
		$d->{'lon'} = $coords[1]+0;
		delete $d->{'loc'};
		if($li > 0){
			for($l = 0; $l < $li; $l++){
				$d->{'li'}[$l] =~ s/[\n\r]//g;
				if($d->{'li'}[$l] =~ /^Address: (.*)/){
					$d->{'address'} = $1;
				}
				if($d->{'li'}[$l] =~ /^Opening hours: (.*)/){
					$d->{'hours'} = parseOpeningHours({'_text'=>$1});;
				}
			}


			# Remove the <li> entry
			delete $d->{'li'};
			delete $d->{'p'};

		}
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

