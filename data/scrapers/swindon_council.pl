#!/usr/bin/perl

use lib "./";
use utf8;
use Data::Dumper;
use Web::Scraper;
require "lib.pl";
binmode STDOUT, 'utf8';

# Get the file to process
$file = $ARGV[0];
$baseurl = "https://www.swindon.gov.uk";

# If the file exists
if(-e $file){

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	# Build a web scraper
	my $warmspaces = scraper {
		process '.site-content__main .item-list--rich li', "warmspaces[]" => scraper {
			process 'a', 'url' => '@HREF';
			process 'a', 'title' => 'TEXT';
		}
	};


	$n = 0;
	$next = "placeholder";
	while($next){
		if($n>0){
			# Get new page here
			$rfile = "raw/swindon_council-page$n.html";
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

		my $res = $warmspaces->scrape( $str );
		$t = @{$res->{'warmspaces'}};

		warning("\tMatched $t warmspaces on page.\n");
		for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
			
			$d = $res->{'warmspaces'}[$i];
			
			if($d->{'url'} =~ /^\//){
				$d->{'url'} = $baseurl.$d->{'url'};
			}

			$d->{'url'} =~ /directory_record\/([^\/]*)\//;
			$record = $1;
			$rfile = "raw/swindon-$record.html";
			
			warning("\t$i = $record\n");

			# Keep cached copy of individual URL
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
				if($key =~ /Address/is){
					$d->{'address'} = trimHTML($value);
				}elsif($key =~ /Opening times/is){
					$d->{'hours'} = trimHTML($value);
				}elsif($key =~ /Facilities/is){
					$d->{'description'} = $value;
					$d->{'description'} =~ s/<\/li>[^\<]*<li>/; /gs;
					$d->{'description'} = "Facilities: ".trimHTML($d->{'description'});
				}
			}
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }

			push(@entries,makeJSON($d,1));
		}


		if($str =~ /"nav--pagination__last".*?<a href="([^\"]+)"><em>Next/s){
			$next = $1;
			if($next =~ /^\//){
				$next = $baseurl.$next;
			}
		}else{
			$next = "";
		}
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