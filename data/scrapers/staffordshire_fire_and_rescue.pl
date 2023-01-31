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
		process '.fafs-location', "warmspaces[]" => scraper {
			process '*', 'coords' => '@data-coordinates';
			process '.title', 'title' => 'TEXT';
			process 'a', 'url' => '@HREF';
			process '.content strong', 'address' => 'TEXT';
			process '.content p', 'p[]' => 'TEXT';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$row = $res->{'warmspaces'}[$i];
		$d = {};
		$d->{'title'} = $row->{'title'};
		$d->{'address'} = $row->{'address'};
		$d->{'url'} = ($row->{'url'} =~ /^\// ? "https://www.staffordshirefire.gov.uk" : "").$row->{'url'};
		if($row->{'coords'} =~ /(.*?)\, (.*)/){
			$d->{'lat'} = sprintf("%.4f",$1);
			$d->{'lon'} = sprintf("%.4f",$2);
		}
		if($row->{'p'}[1]){
			$row->{'p'}[1] =~ s/<[^\>]+>//g;
			$d->{'hours'} = parseOpeningHours({'_text'=>$row->{'p'}[1]});
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