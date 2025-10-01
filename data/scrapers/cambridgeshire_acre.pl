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

	$str =~ s/\&\#8211;/-/g;
	$list = "";
	while($str =~ s/<h4>(.*?)<\/h4>(.*?)<h4>/<h4>/s){
		$list .= $2;
	}

	# Build a web scraper
	my $res = scraper {
		process 'ul li', "warmspaces[]" => 'HTML';
	}->scrape( $list );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = {};
		$content = $res->{'warmspaces'}[$i];
		if($content =~ s/^<b>(.*?)<\/b> ?//){
			$d->{'title'} = $1;
		}
		if($content =~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/){
			$pcd = $2;
			$content =~ /(.*$pcd)/;
			$d->{'address'} = $1;
			$d->{'address'} =~ s/^ ?\- ?//g;
		}
		if($content =~ /href="([^\"]+)"/){
			$d->{'url'} = $1;
		}
		if($content =~ /Opens: (.*)/){
			$d->{'hours'} = {};
			$d->{'hours'}{'_text'} = $1;
			$d->{'hours'}{'_text'} =~ s/<[^\>]+>//g;
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
		}
		if($d->{'title'}){
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

