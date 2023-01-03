#!/usr/bin/perl

use lib "./";
use utf8;
use Data::Dumper;
use Web::Scraper;
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
		process 'div[class="paragraph paragraph--type--localgov-accordion-pane paragraph--view-mode--default accordion-pane"]', "warmspaces[]" => scraper {
			process 'div[class="accordion-pane__title"] h3', 'title' => 'TEXT';
			process 'p', 'p[]' => 'HTML';
		}
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$area = $res->{'warmspaces'}[$i];

		$d = {};
		$d->{'title'} = $area->{'title'};
		$d->{'title'} =~ s/ - ([^\s]+)$//;

		for($p = 0; $p < @{$area->{'p'}}; $p++){
			if($area->{'p'}[$p] =~ /When: ?(.*)/){ $d->{'hours'} = parseOpeningHours({'_text'=>$1}); }
			elsif($area->{'p'}[$p] =~ /Where: ?(.*)/){ $d->{'address'} = trimHTML($1); if($1 =~ /<a[^\>]*href="([^\"]+)"/){ $d->{'url'} = $1; } if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.bracknell-forest.gov.uk".$d->{'url'}; } }
			else{ $d->{'description'} .= ($d->{'description'} ? "\n":"").trimHTML($area->{'p'}[$p]); }
		}

		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}