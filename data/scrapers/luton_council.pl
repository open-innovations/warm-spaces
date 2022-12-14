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
		process 'div[class="card"]', "warmspaces[]" => scraper {
			process 'div[class="card-header"]', 'title' => 'TEXT';
			process 'div[class="card-body"] div[class="card-footer"]', 'description' => 'TEXT';
			process 'div[class="card-body"] li', 'li[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$li = @{$d->{'li'}};
		
		if($d->{'description'} eq "Additional activities:"){ delete $d->{'description'}; }
		if($li > 0){
			for($l = 0; $l < $li; $l++){
				$d->{'li'}[$l] =~ s/<br ?\/?>/ /g;
				$d->{'li'}[$l] =~ s/<[^\>]+>//g;
				if($d->{'li'}[$l] =~ /Time: (.*)/){ $d->{'hours'} = parseOpeningHours({'_text'=>$1}); }
				if($d->{'li'}[$l] =~ /Where to go: (.*)/){ $d->{'address'} = $1; }
			}

			# Remove the <li> entry
			delete $d->{'li'};

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

