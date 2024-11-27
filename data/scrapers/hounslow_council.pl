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
	$str =~ s/\&ndash;/-/g;

	# Build a web scraper
	my $warmspaces = scraper {
		process 'div[class="widget_content byEditor by_editor editor"] table tr', "warmspaces[]" => scraper {
			process "td", "td[]" => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){
		$place = $res->{'warmspaces'}[$i];
		$d = {};
		
		$d->{'title'} = $place->{'td'}[1];

		$d->{'address'} = parseText($place->{'td'}[2]);

		if($place->{'td'}[5] =~ /href="([^\"]+)"/){
			$d->{'url'} = $1;
		}

		if($place->{'td'}[6]){
			$d->{'description'} = parseText($place->{'td'}[6]);
			$d->{'description'} =~ s/[\s]\,/\,/g;
			$d->{'description'} =~ s/\,$//g;
		}

		$place->{'td'}[7] =~ s/(^\"|\"$)//g;
		$hours = $place->{'td'}[7].($place->{'td'}[7] !~ /\.$/ ? ". ":"").$place->{'td'}[8];
		$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($hours)});

		while($place->{'td'}[9] =~ s/<li>(.*?)<\/li>//){
			$txt = $1;
			if($txt =~ /[0-9 ]{8,}/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: $txt";
			}elsif($txt =~ /mailto:([^\"]+)/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: $1";
			}
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}