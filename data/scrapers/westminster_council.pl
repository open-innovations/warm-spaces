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
	
	
	# Build a web scraper
	my $warmspaces = scraper {
		process 'article.node .text-long', "warmspace" => 'HTML';
	};

	$html = $warmspaces->scrape($str)->{'warmspace'};

	while($html =~ s/<h3>(.*?)<\/h3>(.*?)(<h3>|$)/<h3>/){
		$d = {};
		$d->{'title'} = $1;
		$p = $2;
		if($p =~ /<a [^\>]*href="([^\"]*)"/){
			$d->{'url'} = $1;
			if($d->{'url'} =~ /^\//){
				$d->{'url'} = "https://www.westminster.gov.uk".$d->{'url'};
			}
		}
		if($d->{'url'} =~ /^mailto:/){ delete $d->{'url'}; }
		if(!$d->{'url'} && $p =~ s/Website: ?([^\s]*)//i){
			$d->{'url'} = $1;
		}
		if($p =~ s/<p>Address: ?(.*?)<\/p>//){
			$d->{'address'} = $1;
		}
#		if($p =~ s/email: <a [^\>]&href="mailto:([^\"]*)"[^\>]*>(.*?)<\/a>//i){
#			$d->{'contact'} = "Email: $1";
		if($p =~ /<p>([^\<]*(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)[^\<]*)<\/p>/i){
			$d->{'hours'} = parseOpeningHours({'_text'=>$1});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
		}
		$p = trimHTML($p);
		if($p =~ s/Email: ?([^\;]*)\;? ?//i){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: $1";
		}
		if($p =~ s/Phone: ?([0-9\s]{6,})\;? ?//i){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Telephone: $1";
		}

		$d->{'description'} = $p;

		# Store the entry as JSON
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
	$str =~ s/([^\.])(<\/li>|<\/p>)/$1; /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/\;\s\.?\s?\;/\;/g;
	$str =~ s/ ?\;$//g;
	$str =~ s/^\. //g;
	$str =~ s/\s\;\s/\; /g;
	$str =~ s/\;\s+$//g;
	return $str;
}