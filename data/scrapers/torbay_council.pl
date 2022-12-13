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
	
	$str =~ s/[\n\r]/ /g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	if($str =~ /var myPoints = (\[.*?\]);/s){

		$str = $1;
		$str =~ s/\,[\n\s\t]*\]/\]/g;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);	

		for($i = 0; $i < @{$json}; $i++){
			$d = {};
			$d->{'lat'} = $json->[$i][0]+0;
			$d->{'lon'} = $json->[$i][1]+0;
			if($json->[$i][2] =~ /<h4[^\>]*>(.*?)<\/h4>/){
				$d->{'title'} = $1;
			}
			if($json->[$i][2] =~ /<a href=['"]([^\"\']+)['"]>/){
				$d->{'url'} = $1;
			}
			if($json->[$i][2] =~ /<p[^\>]*>(.*?)<\/p>/){
				$d->{'description'} = $1;
				$d->{'description'} =~ s/(Find out more)/<a href="$d->{'url'}">$1<\/a>/;
			}
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

