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


	# Build a web scraper
	my $warmspaces = scraper {
		process '.views-row', "warmspaces[]" => scraper {
			process 'h3', 'title' => 'TEXT';
			process 'h3 a', 'url' => '@HREF';
			process '.field--type-text-with-summary', 'description' => 'TEXT';
		}
	};
	my $res = $warmspaces->scrape( $str );

	my $features = {};
	if($str =~ /"features":(\[.*?\])/){
		$fs = JSON::XS->new->decode($1);
		for($i = 0; $i < @{$fs};$i++){
			$features->{$fs->[$i]{'title'}} = $fs->[$i];
		}
	}

	my $warmspace = scraper {
		process '.localgov-directories-venue .field--type-text-with-summary', "description" => 'HTML';
		process '.field--name-postal-address', "address" => 'HTML';
		process '.field--name-localgov-directory-opening-times tr', "hours[]" => 'HTML';
		process '.field--name-localgov-directory-website a', "url" => '@HREF';
	};

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$d->{'title'} =~ s/\s$//g;
		if($features->{$d->{'title'}}){
			$d->{'lat'} = $features->{$d->{'title'}}{'lat'};
			$d->{'lon'} = $features->{$d->{'title'}}{'lon'};
		}

		if($d->{'url'} =~ /\/communities\/warm-spaces-directory\//){
			$d->{'url'} = "https://www.westdevon.gov.uk".$d->{'url'};

			# Get the URL
			$rfile = "raw/west-devon-".($i+1).".html";
			
			warning("\tGetting details for $i\n");

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
			$str = join("",@lines);
			$warm = $warmspace->scrape($str);

			if($warm->{'url'}){ $d->{'url'} = $warm->{'url'}; }
			if($warm->{'address'}){
				$warm->{'address'} =~ s/<br\s?\/?>/, /g;
				$d->{'address'} = trimHTML($warm->{'address'});
				$d->{'address'} =~ s/ , /, /g;
				$d->{'address'} =~ s/^Address ?//g;
			}
			if($warm->{'description'}){
				$warm->{'description'} =~ s/<strong>Services<\/strong>/Services:/g;
				$warm->{'description'} =~ s/<\/li><li>/; /g;
				$d->{'description'} = trimHTML($warm->{'description'});
			}
			if($warm->{'hours'}){
				for($h = 0; $h < @{$warm->{'hours'}}; $h++){
					$warm->{'hours'}[$h] =~ s/<\/td><td>/ /g;
					$warm->{'hours'}[$h] = trimHTML($warm->{'hours'}[$h]);
				}
				$d->{'hours'} = parseOpeningHours({'_text'=>parseText(join(";",@{$warm->{'hours'}}))});
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

sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
