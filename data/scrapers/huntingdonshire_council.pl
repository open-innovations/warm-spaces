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

		process 'div[class="collapsible-content-block"]', "warmspaces[]" => scraper {
#			# And, in each DIV,
			process 'h3', 'title' => 'TEXT';
			process 'li', "li[]" => "TEXT";
			process 'tbody tr', "tr[]" => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

#print Dumper $res;
	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){

		$d = $res->{'warmspaces'}[$i];

		$d->{'description'} = '';
		for($li = 0; $li < @{$d->{'li'}}; $li++){ $d->{'description'} .= ($d->{'description'} ? ", ":"").$d->{'li'}[$li]; }
		$d->{'description'} = "Facilities: ".$d->{'description'};

		# Remove the <li> entry
		delete $d->{'li'};

		if($d->{'tr'}){
			$d->{'hours'} = {'_text'=>''};
			my $rowprocess = scraper {
				process 'td', 'td[]' => 'TEXT'
			};
			for($r = 0; $r < @{$d->{'tr'}}; $r++){
				my $row = $rowprocess->scrape( $d->{'tr'}[$r] );
				$d->{'hours'}{'_text'} .= ($d->{'hours'}{'_text'} ? ", ":"").($row->{'td'}[0].": ".$row->{'td'}[1]);
			}
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
			delete $d->{'tr'};
		}

		# If we have opening hours, parse them
		if($d->{'hours'}){ $d->{'hours'} = parseOpeningHours($d->{'hours'}); }

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

