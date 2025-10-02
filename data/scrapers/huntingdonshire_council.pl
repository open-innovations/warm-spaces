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
			process 'h3', 'address' => 'TEXT';
			process 'p', "p[]" => "HTML";
			process 'li', "li[]" => "TEXT";
			process 'div[class="collapsible-content"]', 'content' => 'HTML';
			process 'table tbody tr', 'tr[]' => scraper {
				process 'td', 'td[]' => 'HTML';
			};
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){

		$d = $res->{'warmspaces'}[$i];

		$d->{'description'} = '';
		for($p = 0; $p < @{$d->{'p'}}; $p++){
			if($d->{'p'}[$p] =~ /mailto:([^\"]+)/){
				$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Email: ".$1;
			}elsif($d->{'p'}[$p] =~ /href="([^\"]+)"/){
				$d->{'url'} = $1;
			}else{
				$d->{'description'} .= ($d->{'description'} ? ", ":"").$d->{'p'}[$p];
			}
		}
		
		$facilities = "";
		for($li = 0; $li < @{$d->{'li'}}; $li++){
			$facilities .= ($facilities ? ", ":"").$d->{'li'}[$li];
		}
		if($facilities){
			$d->{'description'} .= "Facilities: ".$facilities;
		}

		if($d->{'content'} =~ /<h3>Opening times<\/h3>\n*[\t\s]*<p>(.*?)<\/p>/si){
			$temp = $1;
			$temp =~ s/<br ?\/?>/; /g;
			$d->{'hours'} = parseOpeningHours({'_text'=>$temp});
		}

		delete $d->{'li'};
		delete $d->{'content'};
		delete $d->{'tr'};

		# Remove the <li> entry
		delete $d->{'li'};
		delete $d->{'p'};
		delete $d->{'tr'};

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

