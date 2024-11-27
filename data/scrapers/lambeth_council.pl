#!/usr/bin/perl

use lib "./";
use utf8;
use Data::Dumper;
use Web::Scraper;
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

	my $warmspace = scraper {
		process 'article.directory-page .address', "address" => 'HTML';
		process '.contact-card__value', 'contact[]' => 'HTML';
		process '.typography table tr', 'tr[]' => 'HTML';
	};

	$n = @features;

	for($i = 0; $i < @features; $i++){
		$d = {};
		$d->{'title'} = $features[$i]{'title'};
		$d->{'lat'} = $features[$i]{'lat'}+0;
		$d->{'lon'} = $features[$i]{'lon'}+0;
		$features[$i]{'popup'}{'value'} =~ s/\\u([0-9a-f]{4})/chr ($1)/eg;
		if($features[$i]{'popup'}{'value'} =~ /<a href=\"([^\"]*)\">/s){

			$d->{'url'} = $1;
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.lambeth.gov.uk".$d->{'url'}; }
			if($d->{'url'} =~ /^https:\/\/www.lambeth.gov.uk\//){
				$url = $d->{'url'};
				$rfile = "raw/lambeth_council_$i.html";
				# Keep cached copy of individual URL
				$age = getFileAge($rfile);
				if($age >= 86400 || -s $rfile == 0){
					warning("\tSaving <green>$url<none> to <cyan>$rfile<none>\n");
					# For each entry we now need to get the sub page to find the location information
					`curl '$url' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1' -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0" -H "Accept-Language: en-GB,en;q=0.5" -H "Accept-Encoding: gzip, deflate"`;
				}
				open(FILE,"<:utf8",$rfile);
				@lines = <FILE>;
				close(FILE);
				$str = join("",@lines);
				my $res = $warmspace->scrape($str);
				if($res->{'address'}){
					$d->{'address'} = trimText($res->{'address'});
					$d->{'address'} =~ s/ <br \/> /, /g;
				}
				if($res->{'contact'}[0] !~ /<a/){
					$d->{'contact'} = trimText($res->{'contact'}[0]);
				}
				for($c = 0; $c < @{$res->{'contact'}}; $c++){
					if($res->{'contact'}[$c] =~ /tel:([0-9 ]+)/){
						$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$1;
					}
					if($res->{'contact'}[$c] =~ /mailto:([^\"]+)/){
						$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$1;
					}
					if($res->{'contact'}[$c] =~ /href="(http[^\"]+)"/){
						$d->{'url'} = $1;
					}
				}
				
				$hours = "";
				for($r = 0; $r < @{$res->{'tr'}}; $r++){
					if($res->{'tr'}[$r] =~ /<t[dh]>([^\>]*)<\/t[dh]><t[dh]>([^\>]*)<\/t[dh]>/){
						$day = $1;
						$time = $2;
						if($day =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|holidays)/i){
							$hours .= ($hours ? "; ":"")."$day $time";
						}
					}
				}
				if($hours){
					$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
					if(!defined($d->{'hours'}{'opening'})){ delete $d->{'hours'}; }
				}
			}
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

