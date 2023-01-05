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
		process 'ul[class="content-items wysiwyg"] tr', "warmspaces[]" => 'HTML';
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$row = $res->{'warmspaces'}[$i];
		$row =~ s/<td>//g;
		@td = split(/<\/td>/,$row);

		if(@td == 4){
			$d = {};
			$d->{'title'} = trimHTML($td[0]);
			if($td[0] =~ /<a href="([^\"]+)"/){ $d->{'url'} = $1; if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.belfastcity.gov.uk".$d->{'url'}; } }
			$d->{'hours'} = parseText($td[1].' '.$td[2]);
			if($td[3]){ $d->{'contact'} = "Tel: ".parseText($td[3]); }
			push(@entries,$d);
		}elsif(@td == 2){
			$entries[@entries-1]->{'hours'} .= "; ".parseText($td[0].' '.$td[1]);
		}
	}
	
	for($i = 0; $i < @entries; $i++){
		
		# For each entry we now need to get the sub page to find the location information
		$html = `wget -q --no-check-certificate -O- "$entries[$i]->{'url'}"`;
		if($html =~ /initMapSingle\('sideMap', ([^\,]+), ([^\,]+), [0-9]+, 'marker'\);/){
			$entries[$i]->{'lat'} = $1;
			$entries[$i]->{'lon'} = $2;
		}
		$entries[$i]->{'hours'} = parseOpeningHours({'_text'=>$entries[$i]->{'hours'}});
		if(!$entries[$i]->{'hours'}{'opening'}){ delete $entries[$i]->{'hours'}{'opening'}; }
		$entries[$i] = makeJSON($entries[$i],1);
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