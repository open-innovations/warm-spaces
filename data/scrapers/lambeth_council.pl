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

	my @features;
	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	if($str =~ / <script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/s){

		$jsonstr = $1;
		if(!$jsonstr){ $jsonstr = "{}"; }
		$json = JSON::XS->new->decode($jsonstr);
		push(@features,@{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}});
		$n = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};

	}

	$n = @features;

	for($i = 0; $i < @features; $i++){
		$d = {};
		$d->{'title'} = $features[$i]{'label'};
		$d->{'lat'} = $features[$i]{'lat'}+0;
		$d->{'lon'} = $features[$i]{'lon'}+0;
		$features[$i]{'popup'} =~ s/\\u([0-9a-f]{4})/chr ($1)/eg;
		if($features[$i]{'popup'} =~ /<h3 class=\"order-1 w-full title listing-card__title\">[\n\r\s\t]*<a href=\"([^\"]*)\">/s){
			$d->{'url'} = $1;
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://beta.lambeth.gov.uk".$d->{'url'}; }
		}
		if($features[$i]{'popup'} =~ /<div class=\"measure typography\">(.*?)<\/div>/s){
			$d->{'description'} = $1;
			$d->{'description'} =~ s/[\n]/ /g;
			#$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'description'}});
			#if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
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


sub getPage {
	my $file = shift;
	my @features = shift;
	my (@lines,$str,$jsonstr,$json,$url,$pp,$n);
	
	
	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	if($str =~ / <script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/s){

		$jsonstr = $1;
		if(!$jsonstr){ $jsonstr = "{}"; }
		$json = JSON::XS->new->decode($jsonstr);
		push(@features,@{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}});
		$n = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};
		print "Add $n features\n";
	}

#	if($str =~ /<link rel="canonical" href="([^\"]*)"/){
#		$url = $1;
#		# Do we have a next page?
#		if($str =~ /<a href="\?([^\"]+)"[^\>]+title="Go to next page"[^\>]+rel="next"/s){
#			$next = $1;
#			if($next =~ /page=0\%2C([0-9]+)/){ $pp = $1; }
#			$next =~ s/\&amp;/\&/;
#			$url .= "?".$next;
#
#			$file =~ s/\-?[0-9]*(\.html)/-$pp$1/;
#
#			getURLToFile($url,$file);
#			print "Next page = getURLToFile($url,$file)\n";
#			@features = getPage($file,@features);
#		}
#	}
	
	return @features;
}
