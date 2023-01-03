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

	for($i = 0; $i < @{$json->{'content'}}; $i++){
		$place = $json->{'content'}[$i];
		$d = {};
		if($place->{'locations'}[0]){
			$d->{'lat'} = $place->{'locations'}[0]{'geometry'}{'coordinates'}[1];
			$d->{'lon'} = $place->{'locations'}[0]{'geometry'}{'coordinates'}[0];
			$d->{'title'} = $place->{'locations'}[0]{'name'};
			$d->{'address'} = $place->{'locations'}[0]{'address_1'}.($place->{'locations'}[0]{'city'} ? ", ".$place->{'locations'}[0]{'city'} : "").($place->{'locations'}[0]{'postal_code'} ? ", ".$place->{'locations'}[0]{'postal_code'} : "");
			$d->{'contact'} = $place->{'contacts'}[0]{'name'};
			$d->{'contact'} .= ($place->{'contacts'}[0]{'email'} ? ($d->{'contact'} ? ", ":"")."Email: ".$place->{'contacts'}[0]{'email'} : "");
			$d->{'contact'} .= ($place->{'contacts'}[0]{'phone'} ? ($d->{'contact'} ? ", ":"")."Tel: ".$place->{'contacts'}[0]{'phone'} : "");

			for($s = 0; $s < @{$place->{'regular_schedules'}}; $s++){
				$d->{'hours'} .= ($d->{'hours'} ? "; ":"")."$place->{'regular_schedules'}[$s]{'weekday'} $place->{'regular_schedules'}[$s]{'opens_at'} - $place->{'regular_schedules'}[$s]{'closes_at'}";
			}
			if($d->{'hours'}){
				$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			}

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

