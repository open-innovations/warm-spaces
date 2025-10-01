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

	# Trim before and after
	$str =~ s/.*<div class="tabify tabs tabs--accordion">//gs;
	$str =~ s/<\/div>.*//gs;

	while($str =~ s/<h3>([^\<]*)<\/h3>(.*?)<\/ul>//s){
		$d = {};
		$d->{'title'} = $1;
		$list = $2;
		$list =~ s/.*<ul>//g;
		$list =~ s/\n<li>//g;
		$list =~ s/(^\n|\n$)//g;
		@li = split(/<\/li>/,$list);
		for($l = 0; $l < @li; $l++){
			if($li[$l] =~ /<strong>Location:<\/strong> ?(.*)/){
				$d->{'address'} = $1;
			}elsif($li[$l] =~ /<strong>Eligibility:<\/strong> ?(.*)/){
				$d->{'description'} = "Eligibility: ".$1;
			}elsif($li[$l] =~ /<strong>Day and time:<\/strong> ?(.*)/){
				$d->{'hours'} = {'_text'=>$1};
				$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
				$d->{'hours'} = parseOpeningHours($d->{'hours'});
			}
			
			if($li[$l] =~ /tel:([^\"]*)/ || $li[$l] =~ /call ([0-9\s]{8,}[0-9])/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$1;
			}
			if($li[$l] =~ /mailto:([^\"]*)/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$1;
			}
			if($li[$l] =~ /(https:\/\/www.facebook.com\/[^\"]*)/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Facebook: ".$1;
			}
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

