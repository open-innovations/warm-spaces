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


	while($str =~ s/<input type="hidden" id="map_marker_info[^\"]+" value="([^\"]+)">[\n\t\s\r]*<input type="hidden" [^\>]* class="mapMarkers" value="([^\"]+)">//s){

		$a = $1;
		$b = $2;

		$d = {};
		
		if($b =~ /\,/){
			@coord = split(/,/,$b);
			$d->{'lat'} = $coord[0]+0;
			$d->{'lon'} = $coord[1]+0;
			
			$a =~ s/\+/ /g;
			$a =~ s/%([A-Fa-f\d]{2})/chr hex $1/eg;
			if($a =~ /<a href="([^\"]+)">(.*?)<\/a>/){
				$d->{'url'} = $1;
				$d->{'title'} = $2;
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

