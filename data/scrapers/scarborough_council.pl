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
	
	for($i = 0; $i < @{$json->{'records'}}; $i++){
		$area = $json->{'records'}[$i];
		$d = {};
		$d->{'description'} = $area->{'fields'}{'Description'};
		$d->{'address'} = $area->{'fields'}{'Location'};
		$d->{'title'} = $area->{'fields'}{'Name'};
		if($area->{'fields'}{'external link'}){ $d->{'url'} = $area->{'fields'}{'external link'}; }
		$d->{'contact'} = ($area->{'fields'}{'Phone'} ? "Tel: ".$area->{'fields'}{'Phone'} : "");
		$d->{'contact'} .= ($area->{'fields'}{'Email'} ? "Email: ".$area->{'fields'}{'Email'} : "");
		if($area->{'fields'}{'Time'} =~ /([0-9]{1,2}):([0-9]{2}) ?(am|pm)/){
			$hh = $1;
			$mm = $2;
			if($3 eq "pm" && $hh != 12){ $hh += 12; }
			$s = sprintf("%02d",$hh).":".sprintf("%02d",$mm);
			$dh = 0;
			$dm = 0;
			if($area->{'fields'}{'Duration'} =~ /([0-9]{1,2}):([0-9]{2})/){
				$dh = $1;
				$dm = $2;
			}
			$e = ($hh + $mm/60) + ($dh + $dm/60);
			$hh = int($e);
			$mm = ($e-$hh)*60;
			$e = sprintf("%02d",$hh).":".sprintf("%02d",$mm);
			$d->{'hours'} = parseOpeningHours({'_text'=>$area->{'fields'}{'Day'}." ".$s." - ".$e});
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

