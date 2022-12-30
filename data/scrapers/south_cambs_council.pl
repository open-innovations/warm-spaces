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

	$str =~ s/^.*<div[^\>]*class="elementor-widget-container"[^\>]*>(.*?)<\/div>.*$/$1/;

	while($str =~ s/<h4>(.*?)<\/h4>[\n\r\s\t]*<p>(.*?)<\/p>//s){
		$d = {'title'=>trimHTML($1)};
		$content = $2;
		$content =~ s/<\/?span>//g;
		@lines = split(/<br>/,$content);
		for($l = 0; $l < @lines; $l++){
			$lines[$l] = trimHTML($lines[$l]);
			if($lines[$l] =~ /Venue: (.*)/i){ $d->{'address'} = $1; }
			elsif($lines[$l] =~ /Opening times: (.*)/i){ $d->{'hours'} = parseOpeningHours({'_text'=>$1}); }
			elsif($lines[$l] =~ /Open from: (.*)/i){ $d->{'description'} = "Open from ".$1; }
			elsif($lines[$l] =~ /Notes: (.*)/i){ $d->{'description'} = ($d->{'description'} ? " ":"").$1; }
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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/^\, //g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
