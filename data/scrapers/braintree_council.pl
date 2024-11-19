#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
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


	while($str =~ s/ = new AdvancedMarkerElement\(\{.*?position: new google.maps.LatLng\(([0-9\.]+), ([0-9\.\-\+]+)\),.*?buildContent\(\{ id: "([^\"]+)", name: "([^\"]+)",.*?address: "([^\"]+)"//s){
		$d = {'title'=>$4,'lat'=>$1,'lon'=>$2,'url'=>'https://braintree.essexfrontline.org.uk/Library/ServiceDetail/'.$3,'address'=>$5};
		$d->{'title'} =~ s/\&amp;/\&/g;
		$d->{'address'} =~ s/\s+\,/\,/g;
		$d->{'address'} =~ s/\, *\,/\,/g;
		$d->{'address'} =~ s/\,+/\,/g;
		push(@entries,makeJSON($d,1));
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
