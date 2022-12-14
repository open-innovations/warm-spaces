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

	if(!$str){ $str = "{}"; }
	$json = JSON::XS->new->decode($str);
	$html = $json->{'html'};
	$html =~ s/[\n\r\t]/ /g;

	while($html =~ s/<div class="[^\"]*job_listing_tag-warm-spaces[^\>]*data-longitude="([^\"]*)"[^\>]*data-latitude="([^\"]*)"[^\>]*>(.*?)<\/div><div class="md-clear-3//s){
		$d = {'lat'=>$2+0,'lon'=>$1+0};
		$content = $3;
		if($content =~ s/<h3 class="listing-title">\s*<a href="([^\"]*)">(.*?)<\/a>//sg){ $d->{'title'} = trimHTML($2); $d->{'url'} = $1; }
		if($content =~ s/<div class="listing-phone pull-right">(.*?)<\/div>//sg){ $d->{'contact'} = trimHTML($1); }
		if($content =~ s/<span class="listing-address hidden">(.*?)<\/span>//sg){ $d->{'address'} = trimHTML($1); }

		# Store the entry as JSON
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
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
