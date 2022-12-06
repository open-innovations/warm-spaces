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

	$json = JSON::XS->new->decode($str);
	
#	print Dumper $json;

	for($i = 0; $i < @{$json->{'data'}}; $i++){
		$d = {};
		$d->{'lat'} = $json->{'data'}[$i]->{'latitude'}+0;
		$d->{'lon'} = $json->{'data'}[$i]->{'longitude'}+0;
		$d->{'title'} = $json->{'data'}[$i]->{'organisation'}{'name'};
		if($json->{'data'}[$i]->{'address'}){ $d->{'address'} = $json->{'data'}[$i]->{'address'}; }
		if($json->{'data'}[$i]->{'contact_name'}){ $d->{'contact'} = $json->{'data'}[$i]->{'contact_name'}; }
		if($json->{'data'}[$i]->{'description'}){
			$d->{'description'} = $json->{'data'}[$i]->{'description'};
			$d->{'description'} =~ s/<p>[\n\r\t\s]*<\/p>//g;
			$h = parseOpeningHours({'_text'=>$d->{'description'}});
			if($h->{'opening'}){ $d->{'hours'} = $h; }
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

