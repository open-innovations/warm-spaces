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
		process 'table tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$td = @{$d->{'td'}};
		if($td > 0){
			$venue = parseText($d->{'td'}[0]);
			$times = trimHTML($d->{'td'}[1]);
			$avail = $d->{'td'}[2];
			$other = $d->{'td'}[3];

			$venue =~ s/[\n\r]//g;

			$d->{'address'} = $venue;
			if($venue =~ /^([^\,]+)\, ?(.*)$/){
				$d->{'title'} = $1;
				$d->{'address'} = $2;
			}

			# If we have opening hours, parse them
			if($times){
				$times =~ s/ / /g;
				$d->{'hours'} = parseOpeningHours({'_text'=>$times});
			}
			if($avail){ 
				$d->{'description'} = $avail.($avail ? ". ":"").$other;
				$d->{'description'} =~ s/\.+/\./g;
				$d->{'description'} =~ s/ $//g;
			}

			# Remove the <li> entry
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/([^\.])(<\/li>|<\/p>)/$1; /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/\;\s\.?\s?\;/\;/g;
	$str =~ s/ ?\;$//g;
	$str =~ s/^\. //g;
	$str =~ s/\s\;\s/\; /g;
	$str =~ s/\;\s+$//g;
	return $str;
}