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
	$str =~ s/\&amp;/\&/g;
	$str =~ s/\&\#39;/'/g;

	my $pages = scraper {
		process '.large-8 .callout', 'warmspaces[]' =>  scraper {
			process 'h3', 'title' => 'TEXT';
			process 'a', 'links[]' => '@HREF';
			process 'p', 'p[]' => 'HTML';
		};
	};
	$warm = $pages->scrape( $str );
	$warmspaces = {};
	for($i = 0; $i < @{$warm->{'warmspaces'}}; $i++){
		$title = $warm->{'warmspaces'}[$i]{'title'};
		$title =~ s/ \:\:.*//g;
		$warmspaces->{trimText($title)} = {'links'=>$warm->{'warmspaces'}[$i]{'links'},'p'=>$warm->{'warmspaces'}[$i]{'p'}};
	}
	$coords = {};
	
	
	if($str =~ /<script type=\"text\/javascript\">(.*?new google.maps.*?)<\/script>/s){
		$script = $1;
		$script =~ s/^.*?map.setOptions\(\{styles: styles_0\}\)//gs;
		while($script =~ s/var myLatlng = new google.maps.LatLng\(([^\,]+), ([^\\)]+)\).*?(marker_[0-9]+) = createMarker_map\(markerOptions\);.*?marker_[0-9]+.set\("content", "(.*?)"\)\;//s){
			$d = {'lat'=>$1,'lon'=>$2};
			$desc = $4;
			$title = "";
			if($desc =~ /href=\\"([^\"]+)\\"><b>([^\<]+)<\/b>/){
				$d->{'url'} = "https://www.helpandkindness.co.uk".$1;
				$title = $2;
			}
			while($desc =~ s/<br\/>([^\<]+)//){
				$bit = $1;
				if($bit =~ /((\+[0-9]+)?\s*((\(0\)\s?|0|)[0-9]{2,})\s+(([0-9]{3,} ?[0-9]{3,})))/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: $1";
				}
				# Match to a UK postcode
				# https://stackoverflow.com/questions/164979/regex-for-matching-uk-postcodes
				if($bit =~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/){
					$d->{'address'} = $bit;
				}
			}
			$coords->{$title} = $d;
		}

	}
	foreach $title (sort(keys(%{$warmspaces}))){
		$d = {'title'=>$title};
#		print Dumper $coords->{$title};
		if($coords->{$title}{'url'}){
			foreach $bit (sort(keys(%{$coords->{$title}}))){
				$d->{$bit} = $coords->{$title}{$bit};
			}
			if($d->{'lat'}==0){ delete $d->{'lat'}; }
			if($d->{'lon'}==0){ delete $d->{'lon'}; }
			@links = @{$warmspaces->{$title}{'links'}};
			for($i = 0; $i < @links; $i++){
				if($links[$i] =~ /mailto:(.*)/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: $1";
				}
			}
			@ps = @{$warmspaces->{$title}{'p'}};
			for($i = 0; $i < @ps; $i++){
				if($ps[$i] =~ /(.*) ?<a href="[^\"]+">Link for more details<\/a>/){
					$d->{'description'} = $1;
				}
				if($ps[$i] =~ /no longer running/){
					$d = {};
				}
			}
		}
		if($d->{'url'}){
			push(@entries,makeJSON($d,1));
		}
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
