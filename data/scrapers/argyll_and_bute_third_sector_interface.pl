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
	
	# Very simplistic scraping because this is Wordpress generic class-based layout
	my @warmspaces;
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/\&\#8211;/-/g;
	$str =~ s/\&\#8217;/\'/g;
	while($str =~ s/<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow" style="flex-basis:33.33\%">(.*?)<\/div>.*?<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow" style="flex-basis:66.66\%">(.*?)<\/div>//s){
		push(@warmspaces,{'left'=>$1,'right'=>$2});
	}


	for($i = 0; $i < @warmspaces; $i++){

		$d = {};
		if($warmspaces[$i]{'left'} =~ s/<h3[^\>]*>(.*?)<\/h3>//s){
			$d->{'title'} = trimHTML($1);
		}
		if($warmspaces[$i]{'left'} =~ s/<p><em>(.*?)<\/em><\/p>//s){
			$d->{'address'} = trimHTML($1);
			$d->{'address'} =~ s/,([^\s])/, $1/g;
		}
		$temp = $warmspaces[$i]{'right'};
		$hrs = "";
		while($temp =~ s/<strong>(.*?)<\/strong>//){
			$hrs .= ($hrs ? ". ":"").$1;
		}
		if($hrs){
			$d->{'hours'} = parseOpeningHours({'_text'=>$hrs});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
		}
		$d->{'description'} = trimHTML($warmspaces[$i]{'right'});

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
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}