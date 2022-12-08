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

	if($str =~ /<div class="a-body__inner">(.*?)<\/div>/s){
		$str = $1;
		while($str =~ s/<h2>(.*?)<\/h2>(.*?)<h2>/<h2>/){
			$title = $1;
			$content = $2;
			$d = {};
			
			if($title =~ /<a[^\>]*href="([^\"]+)"/){
				$d->{'url'} = $1;
			}
			$title =~ s/<[^\>]*>//g;
			$d->{'title'} = $title;
			
			if($content =~ s/^<p>(.*?)<\/p>//){
				$d->{'address'} = $1;
			}
			if($content =~ s/^<p>(.*?(mailto|[0-9\s]{8,}))<\/p>//){
				$d->{'contact'} = trimHTML($1);
			}
			if($content =~ s/^<p>(.*?(monday|tuesday|wednesday|thursday|friday|saturday|sunday))<\/p>//i){
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($1)});
			}
			$d->{'description'} = trimHTML($content);

			# Store the entry as JSON
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
	$str =~ s/^<[^\>]+>//g;	# Remove initial HTML tags
	$str =~ s/<\/p>/ /g;	# Replace end of paragraphs with semi-colons
	$str =~ s/<ul>/; /g;	# Replace start of list with space
	$str =~ s/<\/li>/; /g;	# Replace end of list item with semi-colons
	$str =~ s/<br ?\/?>/, /g;	# Replace <br> with commas
	$str =~ s/<[^\>]+>//g;	# Remove any remaining tags
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/ {2,}/ /g;	# De-duplicate spaces
	return $str;
}