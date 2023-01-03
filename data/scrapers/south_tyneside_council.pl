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

	while($str =~ s/<h3>(.*?)<\/h3>(.*?)<hr ?\/?>//s){
		$d = {};
		$d->{'title'} = parseText($1);
		$content = $2;
		$content =~ s/\&nbsp;/ /g;
		$content =~ s/[\s]{2,}/ /g;
		if($content =~ s/<p>.*?Address:.*?>(.*?)<br \/>//){
			$d->{'address'} = parseText($1);
		}
		if($content =~ s/<strong>Drop-in[^\<]*(.*?)<strong>/<strong>/){
			$d->{'hours'} = parseOpeningHours({'_text'=>parseText($1)});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		}
		$content =~ s/<br \/>/; /g;
		$content =~ s/<[^\>]+>//g;
		$d->{'description'} = $content;

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
