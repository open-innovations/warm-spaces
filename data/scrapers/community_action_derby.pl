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
	$str =~ s/\&nbsp;/ /g;

	my $rowscraper = scraper {
		process '.container--inner', 'row[]' => 'HTML';
	};
	
	if($str =~ /Warm Welcome Hub List \(by area\)(.*?)<\/div>/s){
		while($str =~ s/<h4>(.*?)<\/h4>(.*?)<hr[^\>]*>//s){
			$d = {};
			$d->{'title'} = $1;
			$content = $2;
			$d->{'title'} =~ s/<[^\>]*>//g;
			if($content =~ /<strong>Address:<\/strong> ([^\<]*)/i){
				$d->{'address'} = $1;
			}
			if($content =~ /<strong>Days\/times:<\/strong> (.*?)<\/p>/is){
				$d->{'hours'} = parseOpeningHours({'_text'=>$1});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
				if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
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

sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\, //g;
	return $str;
}
