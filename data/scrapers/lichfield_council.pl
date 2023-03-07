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

	$str =~ s/[\n\r]+/\n/s;

	@entries = ();
	

#	while($str =~ s/inMyAreaGMapMarker\[[0-9]+\] = createMarker\([^\(]*google.maps.LatLng\(([0-9\.\-\+\,]+?), ([0-9\.\-\+\)]+?)\).*?<a[^\>]*href="([^\"]+)">(.*?)<\/a>.*?\)//s){
#		$d = {'lat'=>sprintf("%0.5f",$1)+0,'lon'=>sprintf("%0.5f",$2)+0,'url'=>$3,'title'=>parseText($4)};
#		push(@entries,makeJSON($d,1));
#	}

	# Build a web scraper
	my $warmspaces = scraper {
		process 'ul.list--record .list__item', "warmspaces[]" => scraper {
			process '.list__link', 'url' => '@HREF';
			process '.list__link', 'title' => 'TEXT';
		}
	};
	my $res = $warmspaces->scrape( $str );

	$n = @{$res->{'warmspaces'}};
	
	warning("\tMatched $n warmspaces on page.\n");
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$d = $res->{'warmspaces'}[$i];
		if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.lichfielddc.gov.uk".$d->{'url'}; }

		$d->{'url'} =~ /directory-record\/([^\/]*)\//;
		$record = $1;
		$rfile = "raw/lichfield-$record.html";
		
		warning("\tGetting details for $i = $record\n");

		# Keep cached copy of individual URL
		$age = getFileAge($rfile);
		if($age >= 86400 || -s $rfile == 0){
			warning("\tSaving $d->{'url'} to <cyan>$rfile<none>\n");
			# For each entry we now need to get the sub page to find the location information
			`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
		}
		open(FILE,"<:utf8",$rfile);
		@lines = <FILE>;
		close(FILE);
		$html = join("",@lines);

		while($html =~ s/<dt[^\>]*>(.*?)<\/dt>[\n\r\t\s]+<dd[^>]*>(.*?)<\/dd>//s){
			$key = $1;
			$value = $2;
			if($key =~ /Organisation name/is){
				$d->{'address'} = trimHTML($value);
			}elsif($key =~ /We can offer/is){
				$d->{'hours'} = trimHTML($value);
				$d->{'description'} = trimHTML($value);
			}elsif($key =~ /Location/is){
				if($value =~ /value="([0-9\.\-]+)\,([\-0-9\.]+)"/){
					$d->{'lat'} = $1;
					$d->{'lon'} = $2;
				}
			}
		}
		$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
		if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }

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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}