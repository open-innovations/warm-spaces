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

	@items = @{$json->{'items'}};

	for($i = 0; $i < @items; $i++){
		$d = {};
		$d->{'title'} = $items[$i]{'title'};
		$d->{'lat'} = $items[$i]{'location'}{'mapLat'};
		$d->{'lon'} = $items[$i]{'location'}{'mapLng'};
		$d->{'address'} = $items[$i]{'location'}{'addressLine1'};
		$d->{'address'} .= ($d->{'address'} ? ", ":"").$items[$i]{'location'}{'addressLine2'};
		$d->{'address'} .= ($d->{'address'} ? ", ":"").$items[$i]{'location'}{'addressCountry'};

		if($items[$i]{'excerpt'} =~ /Opening Hours:(.*?)<br>/i){
			$d->{'hours'} = parseOpeningHours({'_text'=>parseText($1)});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		}
		if($items[$i]{'excerpt'} =~ /Location Features:(.*?)<p/i){
			$d->{'description'} = parseText($1);
		}
		if($items[$i]{'excerpt'} =~ /<a href=\"([^\"]+)\">Find out more<\/a>/){
			$d->{'url'} = $1;
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

