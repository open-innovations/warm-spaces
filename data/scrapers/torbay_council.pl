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
	
	while($str =~ s/<h3>(.*?)<\/h3>(.*?)(<h3>|<\/div>)/$3/){
		$d = {};
		$d->{'title'} = $1;
		$html = $2;
		if($html =~ s/<p><strong>Address:<\/strong> ?(.*?)<\/p>//){
			$d->{'address'} = $1;
		}
		if($html =~ s/<p><strong>Opening hours:<\/strong> ?(.*?)<\/p>//){
			$d->{'hours'} = parseOpeningHours({'_text'=>$1});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
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

