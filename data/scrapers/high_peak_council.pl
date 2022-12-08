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

	# Replace nbsp
	$str =~ s/\&nbsp;/ /g;
	# Remove empty paragraphs first - the table has loads of them
	$str =~ s/<p> <\/p>//g;

	# Build a web scraper
	my $warmspaces = scraper {
		process 'div[class="maincontent__bodytext"] table tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$td = @{$d->{'td'}};
		if($td > 0 && $d->{'td'}[1]){
			
			if($d->{'td'}[1] =~ /^<p>(.*?)<\/p>/){
				$place = $1;
				if($place =~ /^(.*?) - (.*?)$/){
					$d->{'title'} = $1;
					$d->{'address'} = $2;
				}
			}
			if($d->{'td'}[2] =~ /^<p>(.*?)<\/p>/){
				$d->{'hours'} = parseOpeningHours({'_text'=>$1});
			}
			if($d->{'td'}[3] =~ /^<p>(.*?)<\/p>/){
				$d->{'description'} = $1;
			}
			if($d->{'td'}[4] =~ /<a href="([^\"]+)"/){
				$d->{'url'} = $1;
			}

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

