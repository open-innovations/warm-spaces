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

	while($str =~ s/ <input type="hidden" id="map_marker_info_([^\"]+)" value="([^\"]+)">[\n\r\s\t]*<input type="hidden" id="([^\"]+)" class="mapMarkers" value="([^\"\,]+)\,([^\"]+)">//s){
		$a = urldecode($2);
		$d = {'lat'=>$4+0,'lon'=>$5+0};
		if($a =~ /href="([^\"]+)">(.*?)<\/a>/){
			$d->{'url'} = $1;
			$d->{'title'} = $2;
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.coventry.gov.uk".$d->{'url'}; }
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

