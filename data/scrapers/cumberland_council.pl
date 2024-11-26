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

	my $baseurl = "https://www.cumberland.gov.uk";
	my %places;

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
	$str = $content;

	# Get pages
	my $pageparser = scraper {
		process 'ul.pager__items li a', 'url[]' => '@HREF';
	};
	my @pages = @{$pageparser->scrape($str)->{'url'}};
	my $pp = {};
	for($p = 0; $p < @pages; $p++){
		# Get the page
		$url = $baseurl."/health-and-social-care/health-and-wellbeing/cost-living-and-welfare-support/find-local-support-cost-living-and-welfare".$pages[$p];
		$pp->{$url} = 1;
	}

	foreach $url (sort(keys(%{$pp}))){
		if($url =~ /page=([0-9]+)/){
			$p = $1;
			if($p != "0"){
				$rfile = "raw/cumberland_council-page$p.html";
				# Keep cached copy of individual URL
				$age = getFileAge($rfile);
				if($age >= 86400 || -s $rfile == 0){
					warning("\tSaving $url to <cyan>$rfile<none>\n");
					# For each entry we now need to get the sub page to find the location information
					`curl '$url' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
				}
				open(FILE,"<:utf8",$rfile);
				@lines = <FILE>;
				close(FILE);
				$str = join("",@lines);
			}

			my $res = $listparser->scrape($str);
			
			for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
				$d = $res->{'warmspaces'}[$i];
				$d->{'title'} = trimText($d->{'title'});
				$d->{'url'} = $baseurl.$d->{'url'};

				if($places{$d->{'url'}}){
					
					$rfile = "raw/cumberland_council-$i.html";
					# Keep cached copy of individual URL
					$age = getFileAge($rfile);
					if($age >= 86400 || -s $rfile == 0){
						warning("\tSaving $next to <cyan>$rfile<none>\n");
						# For each entry we now need to get the sub page to find the location information
						`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
					}
					open(FILE,"<:utf8",$rfile);
					@lines = <FILE>;
					close(FILE);
					$str = join("",@lines);
					
					my $warm = $warmparser->scrape($str);
					if($warm->{'opening'}){
						$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($warm->{'opening'})});
					}
					if($warm->{'address'}){
						$d->{'address'} = $warm->{'address'};
						$d->{'address'} =~ s/<br ?\/?>/, /g;
						$d->{'address'} =~ s/<[^\>]+>//g;
					}
					if($warm->{'tel'}){ $d->{'contact'} .= ($d->{'contact'} ? "; " : "").'Tel: '.$warm->{'tel'}; }
					if($warm->{'email'}){ $warm->{'email'} =~ s/mailto://; $d->{'contact'} .= ($d->{'contact'} ? "; " : "").'Email: '.$warm->{'email'}; }
					$d->{'lat'} = $places{$d->{'url'}}->{'lat'};
					$d->{'lon'} = $places{$d->{'url'}}->{'lon'};
					push(@entries,makeJSON($d,1));
				}
			}
		}
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

