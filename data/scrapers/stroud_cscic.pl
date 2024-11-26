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

	$str =~ s/[\n\r]+/\n/s;

	@entries = ();
	
	while($str =~ s/<h3 class="wp-block-heading"><strong>([^\>]+)<\/strong><\/h3>(.*?)(<h|<\/div>)//s){
		$d = {'title'=>$1};
		$entry = $2;
		@lines = ();
		while($entry =~ s/<p>(.*?)<\/p>//){
			$line = $1;
			$line =~ s/<\/?strong>//g;
			$line =~ s/\&\#8211;/-/g;
			push(@lines,$line);
		}
		$d->{'address'} = $lines[0];
		$hours = "";
		for($i = 1; $i < @lines; $i++){
			if($lines[$i] =~ /(mon|tue|wed|thur|fri|sat|sun)/i){
				$lines[$i] =~ s/<br ?\/?>/; /g;
				$hours .= ($hours ? "; ":"").$lines[$i];
			}elsif($lines[$i] =~ /Contact:<br>([0-9\s]+)/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: $1";
				if($lines[$i] =~ s/<a href="mailto:([^\"]+)"[^\>]+>//){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: $1";
				}
				if(!$d->{'url'} && $lines[$i] =~ /<a href="([^\"]+)"/){
					$d->{'url'} = $1;
				}
			}else{
				$lines[$i] =~ s/<a href="([^\"]+)"[^\>]*>[^\<]*<\/a>//;
				$d->{'description'} .= ($d->{'description'} && $d->{'description'} !~ /\.$/ ? ". ":"").trimHTML($lines[$i]);
			}
		}
		if($hours){ 
			$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
		}
#		print Dumper @lines;
#		print "HOURS=$hours\n";
#		print Dumper $d;
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
	$str =~ s/\.{2,}/\./g;
	$str =~ s/\. ?\./\./g;
	return $str;
}
