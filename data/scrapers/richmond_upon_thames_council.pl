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
			process 'span[class="loc"]', 'loc' => 'TEXT';
			process '.serviceDetails div', 'details[]' => 'TEXT';
			process 'ul.fac-list li', 'facilities[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$li = @{$d->{'details'}};
		$d->{'description'} = $d->{'p'};
		delete $d->{'p'};
		@coords = split(/,/,$d->{'loc'});
		$d->{'lat'} = $coords[0]+0;
		$d->{'lon'} = $coords[1]+0;
		delete $d->{'loc'};
		if($li > 0){
			for($l = 0; $l < $li; $l++){
				$d->{'details'}[$l] =~ s/[\n\r]//g;
				if($d->{'details'}[$l] =~ /^Address: ?(.*)/){
					$d->{'address'} = $1;
				}
				if($d->{'details'}[$l] =~ /^Opening hours: ?(.*)/){
					$hours = $1;
					if($hours ne "n/a"){
						$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
					}
				}
				if($d->{'details'}[$l] =~ /^Telephone: ?(.*)/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$1;
				}
				if($d->{'details'}[$l] =~ /^Email: ?(.*)/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$1;
				}
				if($d->{'details'}[$l] =~ /^Entry restrictions: ?(.*)/){
					$entry = $1;
					$d->{'description'} .= ($d->{'description'} ? " ":"").($entry eq "Open to all" ? "":"Entry restrictions: ").$1;
				}
				
			}
			# Remove the <li> entry
			delete $d->{'details'};
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

