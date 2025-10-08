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
	$content = $str;

	my $baseurl = "https://www.westmorlandandfurness.gov.uk";

	# Build a web scraper
	my $listparser = scraper {
		process 'article.lgd-teaser--directory-warm-spot', "warmspaces[]" => scraper {
			process 'h3 > a', 'url' => '@HREF';
			process 'h3', 'title' => 'TEXT';
		};
	};
	# Build a web scraper
	my $warmparser = scraper {
		process 'h1', 'title' => 'TEXT';
		process '.field--name-field-organisation-type .field__item', 'description' => 'HTML';
		process '.field--name-postal-address .address', 'address' => 'HTML';
		process '.localgov-directories-venue__enquiries .field--name-localgov-directory-opening-times .field__item', 'opening' => 'HTML';
		process '.localgov-directories-venue__enquiries .bg-icon__envelope .bg-icon__phone', 'tel' => 'TEXT';
		process '.localgov-directories-venue__enquiries .bg-icon__envelope a', 'email' => '@HREF';
		process '.localgov-directories-venue__enquiries .bg-icon__link a', 'url' => '@HREF';
	};

	# Get list from this page
	$next = "placeholder";
	$n = 0;
	while($next){
		if($n>0){
			# Get new page here
			$rfile = "raw/westmorland_council-page$n.html";
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
			$next = $baseurl."/warmspots".$1;
		}else{
			$next = "";
		}

		# Get the list from this page
		my $res = $listparser->scrape($str);
		for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
			$d = $res->{'warmspaces'}[$i];
			$d->{'title'} = trimText($d->{'title'});
			$d->{'url'} = $baseurl.$d->{'url'};

			$rfile = "raw/westmorland_council-$i.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving <cyan>$d->{'url'}<none> to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);

			if($str =~ /{"type":"point","lat":([^\,]+),"lon":([^\,]+),/){
				$d->{'lat'} = $1+0;
				$d->{'lon'} = $2+0	;
			}

			
			my $warm = $warmparser->scrape($str);
			if($warm->{'opening'}){
				$warm->{'opening'} =~ s/<\/p><p>/\; /g;
				$warm->{'opening'} =~ s/([0-9\.]{1,}(am|pm) to [0-9\.]{1,}(am|pm)) ([0-9\.]{1,}(am|pm) to [0-9\.]{1,}(am|pm))/$1 and $4/gs;
#				print $warm->{'opening'}."\n\n";
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($warm->{'opening'})});
			}
			if($warm->{'address'}){
				$d->{'address'} = $warm->{'address'};
				$d->{'address'} =~ s/<br ?\/?>/, /g;
				$d->{'address'} =~ s/<[^\>]+>//g;
			}
			if($warm->{'tel'}){ $d->{'contact'} .= ($d->{'contact'} ? "; " : "").'Tel: '.$warm->{'tel'}; }
			if($warm->{'email'}){ $warm->{'email'} =~ s/mailto://; $d->{'contact'} .= ($d->{'contact'} ? "; " : "").'Email: '.$warm->{'email'}; }
			push(@entries,makeJSON($d,1));
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

sub trim {
	my $str = $_[0];
	$str =~ s/(^\s|\s$)//g;
	return $str;
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

