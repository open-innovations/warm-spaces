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

	$json = {};
	if($str =~ /<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>/s){
		$txt = $1;
		if(!$txt){ $txt = "{}"; }
		$json = JSON::XS->new->decode($txt);
	}
	for($i = 0; $i < @{$json->{'props'}{'pageProps'}{'levelThreeTabs'}}; $i++){
		$d = {};
		$d->{'title'} = $json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'title'};
		$d->{'address'} = $json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'address'};
		$d->{'address'} =~ s/[\n\r]+/, /g;
		$d->{'url'} = "https://libraries.newham.gov.uk/digital-content/libraries/find-a-library/".$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'canonicalTitle'};

		if($json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'phoneNumber'}){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'phoneNumber'};
		}
		if($json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'emailAddress'}){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'emailAddress'};
		}
		$d->{'lon'} = $json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'locationLng'};
		$d->{'lat'} = $json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'locationLat'};

		$hours = "";
		for($h = 0; $h < @{$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'openHours'}} ; $h++){
			$hours .= ($hours ? "; ":"").$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'openHours'}[$h]{'name'}.": ".$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'openHours'}[$h]{'opens'}." - ".$json->{'props'}{'pageProps'}{'levelThreeTabs'}[$i]{'tabDetail'}{'openHours'}[$h]{'closes'};
		}
		if($hours){
			$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			if(!defined($d->{'hours'}{'opening'})){ delete $d->{'hours'}; }
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

sub trimHTML {
	my $str = $_[0];
	$str =~ s/<\/li>/. /g;	# Replace closing LI tags
	$str =~ s/^<[^\>]+>//g;	# Remove initial HTML tags
	$str =~ s/<\/p>/ /g;	# Replace end of paragraphs with spaces
	$str =~ s/<br ?\/?>/, /g;	# Replace <br> with commas
	$str =~ s/<[^\>]+>//g;	# Remove any remaining tags
	$str =~ s/[\t]+/ /gs;
	$str =~ s/^[\n\r\s]+//gs;
	$str =~ s/[\n\r\s\t]+$//gs;
	$str =~ s/[\n\r]+/ /gs;
	$str =~ s/ {2,}/ /g;	# De-duplicate spaces
	return $str;
}
