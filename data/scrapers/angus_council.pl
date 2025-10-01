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

	while($str =~ s/<h3>(.*?)<\/h3>(.*?)(<hr>|$)//){

		$d = {};
		$d->{'title'} = $1;
		$entry = $2;

		while($entry =~ s/<p>(.*?)<\/p>//){
			$p = $1;
			# Match to a UK postcode
			# https://stackoverflow.com/questions/164979/regex-for-matching-uk-postcodes
			if($p =~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/){
				$address = $p;
				$address =~ s/ ?<br> ?/, /g;
				$address =~ s/\<[^\>]*\>//g;
				$d->{'address'} = $address;
			}elsif($p =~ /href="([^\"]+)"/){
				$url = $1;
				if(!defined($d->{'contact'})){
					$d->{'contact'} = "";
				}
				if($p =~ /tel:([^\"]*)/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$1;
				}elsif($p =~ /mailto:([^\"]*)/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$1;
				}elsif($p =~ /(https:\/\/www.facebook.com\/[^\"]*)/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Facebook: ".$1;
				}else{
					$d->{'url'} = $url;
				}

			}elsif($p =~ /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)/i && $p =~ /(am|pm)/i){
				$d->{'hours'} = {'_text'=>$p};
				$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
				$d->{'hours'} = parseOpeningHours($d->{'hours'});
			}else{
				$p =~ s/\<[^\>]*\>//g;
				$d->{'description'} .= ($d->{'description'} ? " ":"").$p;
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

