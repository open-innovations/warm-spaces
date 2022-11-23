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

	#$str =~ s/[\n\r]/ /g;
#	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	@entries = ();

	if($str =~ s/<div class="com">.*?<hr \/>(.*?)<\/div>//s){
		$str = $1;
		
		while($str =~ s/<h2>([^\<]+)<\/h2>(.*?)<hr \/>//s){
			$title = $1;
			$entry = $2;
			$url = "";
			if($entry =~ /<a href="([^\"]+)">/s){ $url = $1; }
			if($entry =~ /<h3>/s){
				while($entry =~ s/<h3>([^\<]+)<\/h3>[\n\r\t\s]*<p><strong>Open:<\/strong>(.*?)<\/p>[\n\r\t\s]*<p><strong>Times:<\/strong>(.*?)<\/p>//s){
					$d = {'title'=>$title.": ".$1,'hours'=>{'_text'=>$2."".$3}};
					$d->{'hours'} = parseOpeningHours($d->{'hours'});
					if($url){ $d->{'url'} = $url; }
					push(@entries,makeJSON($d,1))
				}
			}else{
				if($entry =~ /<p><strong>Open:<\/strong>(.*?)<\/p>[\n\r\t\s]*<p><strong>Times:<\/strong>(.*?)<\/p>/s){
					$d = {'title'=>$title,'hours'=>{'_text'=>$1."".$2}};
					$d->{'hours'} = parseOpeningHours($d->{'hours'});
					if($url){ $d->{'url'} = $url; }
					push(@entries,makeJSON($d,1))
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

