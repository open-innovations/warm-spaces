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

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	$baseurl = "https://www.croydon.gov.uk";

	# Build a web scraper to find the HTML entries
	my $warmspaces = scraper {
		process '.views-row', "rows[]" => scraper {
			process 'h3 a', 'url' => '@HREF';
			process 'h3', 'title' => 'TEXT';
			process '.field--name-body', 'body' => 'HTML';
			process '.field--name-postal-address', 'address' => 'TEXT';
			process '.field--name-localgov-directory-phone', 'phone' => 'TEXT';
		};
	};

	if($str =~ /<script type="application\/json" data-drupal-selector="drupal-settings-json">(.*?)<\/script>/){
		$txt = $1;
		if(!$txt){ $txt = "{}"; }
		$json = JSON::XS->new->decode($txt);
		@features = @{$json->{'leaflet'}{'leaflet-map-view-localgov-directory-channel-embed-map'}{'features'}};
	}

	for($i = 0; $i < @features; $i++){
		$features[$i];
		$url = "";
		$features[$i]->{'popup'}{'value'} =~ s/[\n\r]//g;
		if($features[$i]->{'popup'}{'value'} =~ /<a href="([^\"]*)" rel="bookmark">/){ $url = $1; }
		if($url ne ""){
			if(!defined($places{$url})){
				$places{$url} = {};
			}
			$places{$url}{'lat'} = $features[$i]->{'lat'};
			$places{$url}{'lon'} = $features[$i]->{'lon'};
			$places{$url}{'title'} = $features[$i]->{'title'};
		}
	}

	$n = 0;
	$next = "placeholder";
	while($next){
		if($n>0){
			# Get new page here
			$rfile = "raw/croydon_council-$n.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $next to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$next' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}
		if($str =~ /"pager__item pager__item--next">.*?<a href="([^\"]+)"/s){
			$next = $baseurl."/warm-spaces-directory".$1;
		}else{
			$next = "";
		}

		# Get the list from this page
		my $list = $warmspaces->scrape( $str );
		for($i = 0; $i < @{$list->{'rows'}}; $i++){
			$url = $list->{'rows'}[$i]->{'url'};
			$d = {};
			if(defined($places{$url})){
				$d->{'lat'} = $places{$url}{'lat'};
				$d->{'lon'} = $places{$url}{'lon'};
				$d->{'title'} = $places{$url}{'title'};
				$d->{'address'} = $list->{'rows'}[$i]->{'address'};
				if($list->{'rows'}[$i]->{'phone'}){ $d->{'contact'} = "Tel: ".$list->{'rows'}[$i]->{'phone'}; }
				$d->{'url'} = $baseurl.$url;
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($list->{'rows'}[$i]{'body'})});
				
				push(@entries,makeJSON($d,1));
			}else{
				warning("Bad $url\n");
			}
		}
		$str = "";
		$n++;
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
