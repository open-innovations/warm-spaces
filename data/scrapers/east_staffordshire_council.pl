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


	# Build a web scraper for list items
	my $warmspaces = scraper {
		process '.field-items li', "warmspaces[]" => 'TEXT';
	};

	$res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = {};
		if($res->{'warmspaces'}[$i] =~ /^([^\,]+?)\, /){
			$d->{'title'} = $1;
			if($res->{'warmspaces'}[$i] =~ s/(^| )running (.*)//){
				$d->{'hours'} = parseOpeningHours({'_text'=>$2});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}
			$d->{'address'} = $res->{'warmspaces'}[$i];
			$d->{'address'} =~ s/\, ?$//g;
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}