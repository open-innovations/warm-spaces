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

	my %services;
	while($str =~ s/data\['([^\']+)'\].services.push\(\{(.*?)\}\)//s){
		$id = $1;
		$entry = $2;
		if(!defined($services{$id})){ $services{$id} = {}; }
		#$d = {};
		if($entry =~ /lat: ([0-9\+\-\.]+)/){ $services{$id}{'lat'} = $1; }
		if($entry =~ /lng: ([0-9\+\-\.]+)/){ $services{$id}{'lon'} = $1; }
		if($entry =~ /url: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'url'} = $1; }
		if($entry =~ /name: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'title'} = $1; }
		if($entry =~ /phone: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'contact'} = "Tel: ".$1; }
		if($entry =~ /address: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'address'} = $1; $services{$id}{'address'} =~ s/\\n/\, /g; $services{$id}{'address'} =~ s/<br ?\\\/?>//g; }
		if($entry =~ /postcode: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'address'} .= ", ".$1; }
	}
	while($str =~ s/data\['([^\']+)'\] = \{(.*?)\}//s){
		$id = $1;
		$entry = $2;
		if(!defined($services{$id})){ $services{$id} = {}; }
		if($entry =~ /lat: ([0-9\+\-\.]+)/){ $services{$id}{'lat'} = $1; }
		if($entry =~ /lng: ([0-9\+\-\.]+)/){ $services{$id}{'lon'} = $1; }
		if($entry =~ /url: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'url'} = $1; }
		if($entry =~ /name: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'title'} = $1; }
		if($entry =~ /phone: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'contact'} = "Tel: ".$1; }
		if($entry =~ /address: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'address'} = $1; $services{$id}{'address'} =~ s/\\n/\, /g; $services{$id}{'address'} =~ s/<br ?\\\/?>//g; }
		if($entry =~ /postcode: [\"\']([^\'\"]+)[\"\']/){ $services{$id}{'address'} .= ", ".$1; }
	}

	foreach $id (sort(keys(%services))){
		push(@entries,makeJSON($services{$id},1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

