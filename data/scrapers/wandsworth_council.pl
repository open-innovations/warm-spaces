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
		process 'div[class="warmspace"]', "warmspaces[]" => scraper {
			process "h3", title => 'TEXT';
			process 'span[class="loc"]', lat => [ 'TEXT', sub { /([\-\+0-9\.]+), ?/; return $1+0; } ];
			process 'span[class="loc"]', lon => [ 'TEXT', sub { /, ?([\-\+0-9\.]+)/; return $1+0; } ];
			process 'p', description => 'TEXT';
			process "li", "li[]" => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];

		for($li = 0; $li < @{$d->{'li'}}; $li++){
			if($d->{'li'}[$li] =~ /Address: (.*)/){ $d->{'address'} = $1; }
			if($d->{'li'}[$li] =~ /Opening hours: ?(.*)/){ $d->{'hours'} = { '_text'=>$1 }; }
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

