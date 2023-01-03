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
		process '.material p', "warmspaces[]" => 'HTML';
	};
	my $res = $warmspaces->scrape( $str );


	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$entry = $res->{'warmspaces'}[$i];
		$d = {};
		if($entry =~ s/^.*?<a href="([^\"]+)">(.*?)<\/a>//){
			$d->{'title'} = $2;
			$d->{'url'} = $1;
			$entry =~ s/.*?<\/strong> ?//;
			$entry =~ s/^ ?- ?//;
			if($entry =~ s/(.*?)<strong>//){
				$d->{'address'} = parseText($1);
			}
			if($entry =~ s/<strong>Opening Hours:[^\<]*(.*?)<strong>/<strong>/i){
				$hours = $1;
				$hours =~ s/\, /; /g;
				$d->{'hours'} = parseOpeningHours({'_text'=>parseText($hours)});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}
			$d->{'description'} = parseText($entry);
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
