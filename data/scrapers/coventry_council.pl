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
	
	$p = 1;
	
	
	# Build a web scraper
	my $warmspaces = scraper {
		process 'dl dt', "dt[]" => 'TEXT';
		process 'dl dd', "dd[]" => 'HTML';
	};


	while($str =~ s/ <input type="hidden" id="map_marker_info_([^\"]+)" value="([^\"]+)">[\n\r\s\t]*<input type="hidden" id="([^\"]+)" class="mapMarkers" value="([^\"\,]+)\,([^\"]+)">//s){
		$a = urldecode($2);
		$d = {'lat'=>$4+0,'lon'=>$5+0};
		if($a =~ /href="([^\"]+)">(.*?)<\/a>/){
			$d->{'url'} = $1;
			$d->{'title'} = $2;
			if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.coventry.gov.uk".$d->{'url'}; }


			$rfile = "raw/coventry_council-$p.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $d->{'url'} to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$html = join("",@lines);
			
			my $res = $warmspaces->scrape( $html );
			@dt = @{$res->{'dt'}};
			@dd = @{$res->{'dd'}};
			for($i = 0; $i < @dt; $i++){
				$dt[$i] =~ s/(^\s|\s$)//g;
				$dd[$i] =~ s/(^\s|\s$)//g;
				if($dt[$i] eq "Address"){
					$d->{'address'} = $dd[$i];
				}
				if($dt[$i] eq "Post Code"){
					$d->{'address'} .= ($d->{'address'} ? " ":"").$dd[$i];
				}
				if($dt[$i] eq "Services/activities"){
					$d->{'description'} .= trimHTML($dd[$i]);
				}
				if($dt[$i] eq "Opening Times"){
					$txt = $dd[$i];
					$txt =~ s/<\/p><p>/; /g;
					$txt =~ s/ \| / /g;
					$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($txt)});
				}
			}
			$p++;

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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}