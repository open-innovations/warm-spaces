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
		process '.results-list li', "warmspaces[]" => scraper {
			process 'h3', 'title' => 'TEXT';
			process 'h3 a', 'url' => '@HREF';
			process '.service_date_displaydate', 'hours' => 'TEXT';
			process 'div.mb-3', 'description' => 'TEXT';
			process '.footer .btn', 'btn[]' => scraper {
				process '*', 'href' => '@HREF';
				process '*', 'txt' => 'TEXT';
			};
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){

		$d = $res->{'warmspaces'}[$i];
		$btn = @{$d->{'btn'}};
		if($btn > 0){
			
			for($b = 0; $b < $btn; $b++){
				if($d->{'btn'}[$b]{'href'} =~ s/mailto\://i){
					$d->{'contact'} .= ($d->{'contact'} ? ", ":"")."Email: ".$d->{'btn'}[$b]{'href'};
				}
				if($d->{'btn'}[$b]{'href'} =~ s/tel\://i){
					$d->{'contact'} .= ($d->{'contact'} ? ", ":"")."Tel: ".parseText($d->{'btn'}[$b]{'txt'});
				}
				if($d->{'btn'}[$b]{'href'} =~ s/maps//i){
					$d->{'address'} = parseText($d->{'btn'}[$b]{'txt'});
				}
				if($d->{'btn'}[$b]{'txt'} =~ /Website/i){
					$d->{'url'} = $d->{'btn'}[$b]{'href'};
				}
			}
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			
			if($d->{'url'} !~ /^http/){
				$d->{'url'} = "https://findyour.islington.gov.uk/".$d->{'url'};
			}

			# Remove the buttons
			delete $d->{'btn'};

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

