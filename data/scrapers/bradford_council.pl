#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
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
	
	if($str =~ /"locations":(\[\{.*\}\])/){
		@results = @{parseJSON("var locations = ".$1."")};
		for($i = 0; $i < @results; $i++){
			$results[$i]->{'lat'} = $results[$i]->{'geolocation'}{'lat'};
			$results[$i]->{'lon'} = $results[$i]->{'geolocation'}{'lng'};
			delete $results[$i]->{'geolocation'};
			delete $results[$i]->{'content'};
			push(@entries,makeJSON($results[$i],1));
		}
	}else{
		warning("No locations in Bradford HTML\n");
	}

	warning("\tSaved to $file.json\n");
	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}




sub parseJSON {
	my $str = $_[0];
	my ($json);
	# Error check for JS variable
	$str =~ s/[^\{]*var [^\{]+ = //g;
	if(!$str){ $str = "{}"; }
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid output in $file.\n"); $json = {}; }
	
	return $json;
}
