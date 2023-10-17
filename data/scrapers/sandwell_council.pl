#!/usr/bin/perl

use lib "./";
use utf8;
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

	while($str =~ s/data\['[^\']+'\].services.push\(\{(.*?)\}\)//s){
		$entry = $1;
		$d = {};
		if($entry =~ /lat: ([0-9\+\-\.]+)/){ $d->{'lat'} = $1; }
		if($entry =~ /lng: ([0-9\+\-\.]+)/){ $d->{'lon'} = $1; }
		if($entry =~ /url: [\"\']([^\'\"]+)[\"\']/){ $d->{'url'} = $1; }
		if($entry =~ /name: [\"\']([^\'\"]+)[\"\']/){ $d->{'title'} = $1; }
		if($entry =~ /phone: [\"\']([^\'\"]+)[\"\']/){ $d->{'contact'} = "Tel: ".$1; }
		if($entry =~ /address: [\"\']([^\'\"]+)[\"\']/){ $d->{'address'} = $1; $d->{'address'} =~ s/\\n/\, /g; $d->{'address'} =~ s/<br ?\\\/?>//g; }
		if($entry =~ /postcode: [\"\']([^\'\"]+)[\"\']/){ $d->{'address'} .= ", ".$1; }
		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

