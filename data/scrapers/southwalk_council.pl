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

	@entries;

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	$str =~ s/[\n\r]/ /g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	# We have to use really simple regex parsing because the structure is linear
	while($str =~ s/<h3>(.*?)<\/h3><p>(.*?)<\/p><h4>Opening times<\/h4><p>(.*?)<\/p>//){
		$d = {'title'=>$1,'address'=>$2,'hours'=>{'_text'=>$3}};
		$d->{'title'} =~ s/<[^\>]*>//g;
		$d->{'title'} =~ s/^ //g;
		$d->{'hours'} = parseOpeningHours($d->{'hours'});
		push(@entries,makeJSON($d));
	}
#	print Dumper @entries;

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

