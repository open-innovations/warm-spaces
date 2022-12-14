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
	

	while($str =~ s/<div class="entry-content" itemprop="text">(.*?)<\/div>/$1/s){
		$content = $1;
		
		while($content =~ s/<h3>(.*?)<\/h3>(.*?)(<h3>|$)/$3/s){
			$title = trimHTML($1);
			$ws = $2;
			($title,@times) = split(/ \| /,$title);
			$times = join(" ",@times);
			$d = {'title'=>$title,'hours'=>parseOpeningHours({'_text'=>$times})};
			if($ws =~ s/<p>(.*?)<br \/>//s){
				$d->{'address'} = $1;
			}
			if($ws =~ s/<p><a href="([^\"]*)\"><br \/>//s){
			}
			$ws =~ s/<h2>.*//g;
			$ws =~ s/<a[^\>]*>.*?<\/a>//g;
			$ws = trimHTML($ws);
			$ws =~ s/\n/; /g;
			$ws =~ s/^\; //g;
			$d->{'description'} = $ws;
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
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]|[\s\t\n\r]$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	return $str;
}
