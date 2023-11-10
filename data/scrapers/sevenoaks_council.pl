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

	# Build a web scraper
	my $warmspaces = scraper {
		process 'ul.item-list--rich li', "warmspaces[]" => scraper {
			process 'a', 'title' => 'TEXT';
			process 'a', 'url' => '@HREF';
		}
	};
	
	my $warmspace = scraper {
		process 'article dl', "dl" => scraper {
			process 'dt', 'title[]' => 'TEXT';
			process 'dd', 'content[]' => 'HTML';
		}
	};
	
	$res = $warmspaces->scrape($str);

	for($j = 0; $j < @{$res->{'warmspaces'}}; $j++){
		$d = $res->{'warmspaces'}[$j];

		if($d->{'url'} =~ /^\/directory_record\/([0-9]+)\//){
			$id = $1;
			$d->{'url'} = "https://www.sevenoaks.gov.uk".$d->{'url'};
			$rfile = "raw/sevenoaks_$id.html";

			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving <green>$d->{'url'}<none> to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);

			$warm = $warmspace->scrape($str);
			$dl = $warms->{'dl'};


			for($i = 0; $i < @{$warm->{'dl'}{'title'}}; $i++){
				
				$warm->{'dl'}{'content'}[$i] =~ s/(^ | $)//g;
				
				if($warm->{'dl'}{'title'}[$i] eq "Address"){
					$d->{'address'} = $warm->{'dl'}{'content'}[$i];
				}
				if($warm->{'dl'}{'title'}[$i] eq "Contact name for any queries"){
					$d->{'contact'} .= ($d->{'contact'} ? " ":"")."".$warm->{'dl'}{'content'}[$i];
				}
				if($warm->{'dl'}{'title'}[$i] eq "Telephone number"){
					$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Tel: ".$warm->{'dl'}{'content'}[$i];
				}
				if($warm->{'dl'}{'title'}[$i] eq "Email address"){
					$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Email: ".$warm->{'dl'}{'content'}[$i];
				}
				if($warm->{'dl'}{'title'}[$i] eq "What people can expect when they visit"){
					$d->{'description'} .= ($d->{'description'} ? " ":"").$warm->{'dl'}{'content'}[$i];
				}
				if($warm->{'dl'}{'title'}[$i] eq "Facilities available"){
					$d->{'description'} .= ($d->{'description'} ? " ":"")."Facilities: ".trimHTML($warm->{'dl'}{'content'}[$i]);
				}
				if($warm->{'dl'}{'title'}[$i] eq "Days and times the Warm Space is available"){
					$d->{'hours'} = parseOpeningHours({'_text'=>$warm->{'dl'}{'content'}[$i]});
					if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
				}
				if($str =~ /<input type="hidden" id="map_marker_location_[^\>]*" value="([0-9\.\-\+]+),([0-9\.\-\+]+)">/){
					$d->{'lat'} = $1;
					$d->{'lon'} = $2;
				}
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
