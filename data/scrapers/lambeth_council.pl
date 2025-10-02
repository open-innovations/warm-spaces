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


	$coords = {};

	# Get map coordinates
	if($str =~ / <script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/s){

		$jsonstr = $1;
		if(!$jsonstr){ $jsonstr = "{}"; }
		$json = JSON::XS->new->decode($jsonstr);

		@features = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};
		for($i = 0; $i < @features; $i++){
			if($features[$i]{'popup'}{'value'} =~ /<a href="([^\"]+)">([^\<]*)<\/a>/){
				$coords->{$1} = {'title'=>$2,'lat'=>$features[$i]{'lat'},'lon'=>$features[$i]{'lon'}};
			}
		}
	}

	# Get the pages
	my $pscraper = scraper {
		process '.pager__item a', "pages[]" => '@HREF';
	};
	@pages = @{$pscraper->scrape($str)->{'pages'}};
	$ps = {};
	for($p = 0; $p < @pages; $p++){ $ps->{"https://www.lambeth.gov.uk/warm-spaces".$pages[$p]} = 1; }
	@pages = sort(keys(%{$ps}));


	# Build a web scraper
	my $searchresults = scraper {
		process 'li.mb-8', "results[]" => scraper {
			process 'h3', 'title' => 'TEXT';
			process 'a', 'url' => '@HREF';
		};
	};
	
	my $warmspace = scraper {
		process 'h1.h1--page-title','title' => 'TEXT';
		process 'article.directory-page .measure p', "p[]" => 'HTML';
		process 'article.directory-page .address', "address" => 'TEXT';
		process '.contact-card', 'contacts' => 'HTML';
		process 'article.directory-page .typography', 'typography[]' => 'HTML';
	};

	# Loop through pages
	for($p = 0; $p < @pages; $p++){

		# If we don't already have a string we download the page
		if(!$str){
			$url = $pages[$p];
			$rfile = "raw/lambeth_council-$p.html";
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
		}
		my $res = $searchresults->scrape($str);
		@features = @{$res->{'results'}};

		# Loop over search results
		for($f = 0; $f < @features; $f++){
			$d = {};
			$d->{'title'} = $features[$f]{'title'};
			$d->{'url'} = "https://www.lambeth.gov.uk".$features[$f]{'url'};
			if($coords->{$features[$f]{'url'}}){
				$d->{'lat'} = $coords->{$features[$f]{'url'}}{'lat'};
				$d->{'lon'} = $coords->{$features[$f]{'url'}}{'lon'};
			}

			# Get result details
			$url = $d->{'url'};
			$rfile = "raw/lambeth_council-$p-$f.html";
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
			$str =~ s/’/'/g;
			
			$w = $warmspace->scrape($str);
			$hours = "";

			$d->{'description'} = $w->{'typography'}[0];
			$d->{'description'} =~ s/<[^\>]*>/ /g;
			$d->{'description'} =~ s/\s+/ /g;
			$d->{'description'} =~ s/(^ | $)//g;
			
			$d->{'address'} = $w->{'address'};

			for($t = 0; $t < @{$w->{'typography'}}; $t++){
				if($w->{'typography'}[$t] =~ /Opening times.*<tbody>(.*?)<\/tbody>/i){
					$hours = $1;
					$hours =~ s/<\/tr>/; /g;
					$hours =~ s/<[^\>]*>/ /g;
					$hours =~ s/ +/ /g;
					$hours =~ s/ \;/;/g;
				}elsif($w->{'typography'}[$t] =~ /Opening times.*<p>(.*?)<\/p>/i){
					$hours = $1;
				}elsif($w->{'typography'}[$t] =~ /Accessibility.*<p>(.*?)<\/p>/){
					$d->{'description'} .= " Accessibility: $1";
				}elsif($w->{'typography'}[$t] =~ /tel:([^\"]+)/){
					$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Telephone: ".$1;
				}elsif($w->{'typography'}[$t] =~ /mailto:([^\"]+)/){
					$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Email: ".$1;
				}
			}

			if($hours){
				$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
				if(!defined($d->{'hours'}{'opening'})){ delete $d->{'hours'}; }
			}

			push(@entries,makeJSON($d,1));
		}

		# Reset the string
		$str = "";
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

