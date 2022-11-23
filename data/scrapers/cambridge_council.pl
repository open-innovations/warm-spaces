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
		process 'div[class="row desktop-width "] > div > ul > li', "warmspaces[]" => scraper {
			process 'a', 'url' => '@href';
			#process 'a', 'udi' => '@data-udi';
			process 'a', 'title' => [ 'TEXT', sub { s/( ?poster| ?\[[^\]]+\])//g } ];
			process 'ul > li', 'li[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		if($d->{'url'} =~ /^\//){
			$d->{'url'} = "https://www.cambridge.gov.uk".$d->{'url'};
		}
		for($j = 0; $j < @{$d->{'li'}}; $j++){
			if($d->{'li'}[$j] =~ /Address: (.*)/){
				$d->{'address'} = $1;
			}elsif($d->{'li'}[$j] =~ /(Mondays|Tuesdays|Wednesdays|Thursdays|Fridays|Saturdays|Sundays)\, (.*)/){
				if(!$d->{'hours'}){ $d->{'hours'} = {'_text'=>''}; }
				$d->{'hours'}{'_text'} .= ($d->{'hours'}{'_text'} ? "; " : "").$d->{'li'}[$j];
			}else{
				$d->{'description'} .= ($d->{'description'} ? ", " : "").$d->{'li'}[$j];
			}
		}

		# If we have opening hours, parse them
		if($d->{'hours'}){
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		}

		# Remove the <li> entry
		delete $d->{'li'};

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

