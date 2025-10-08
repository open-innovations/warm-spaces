#!/usr/bin/perl

use lib "./";
use utf8;
use Web::Scraper;
use Data::Dumper;
use Geo::Coordinates::OSGB qw(ll_to_grid grid_to_ll);
require "lib.pl";
binmode STDOUT, 'utf8';

# Get the file to process
$file = $ARGV[0];

# If the file exists
if(-e $file){

	# Open the file
	$json = getJSON($file);
	
	foreach $id (sort(keys(%{$json->{'data'}}))){
		$d = {};
		$d->{'title'} = $json->{'data'}{$id}{'name_of_vn'};
		$d->{'address'} = $json->{'data'}{$id}{'address'};
		if($json->{'data'}{$id}{'eastings'} && $json->{'data'}{$id}{'northings'}){
			($lat,$lon) = grid_to_ll($json->{'data'}{$id}{'eastings'},$json->{'data'}{$id}{'northings'});
			$d->{'lat'} = $lat+0;
			$d->{'lon'} = $lon+0;
		}
		$d->{'hours'} = parseOpeningHours({'_text'=>$json->{'data'}{$id}{'opening_da'}});
		$d->{'contact'} .= ($json->{'data'}{$id}{'phone_numb'} ? ($d->{'contact'} ? "; " : "")."Tel: ".$json->{'data'}{$id}{'phone_numb'} : "");
		$d->{'contact'} .= ($json->{'data'}{$id}{'email_addr'} ? ($d->{'contact'} ? "; " : "")."Email: ".$json->{'data'}{$id}{'email_addr'} : "");

		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

