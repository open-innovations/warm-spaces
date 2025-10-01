#!/usr/bin/perl

use lib "./";
use utf8;
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

	if($str =~ /<div class="topic-paragraphs">(.*?)<\/div>/s){
		while($str =~ s/<h3>(.*?)<\/h3>(.*?)<h3>/<h3>/s){
			$title = $1;
			$content = $2;
			$d = {};
			if($title =~ /^([^\,]*)\,? ?(.*)$/){
				$d->{'title'} = $1;
				if($2){ $d->{'address'} = $2; }
			}
			$content =~ s/\n//g;
			$d->{'description'} = trim($content);

			if($content =~ /<a class="btn-style-primary" [^>]*href="([^\"]+)"/s){
				$d->{'url'} = $1;
				if($d->{'url'} =~ /mailto:(.*)/){
					$d->{'contact'} = "Email: $1";
					delete $d->{'url'};
				}
			}

			$d->{'hours'} = parseOpeningHours({'_text'=>trim($content)});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }

			if($d->{'address'}){
				push(@entries,makeJSON($d,1));
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>/ /g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/ , /, /g;
	return $str;
}
