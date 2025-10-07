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
	$str =~ s/^.*<!-- CONTENT -->(.*)<!-- RELATED LINKS -->.*$/$1/s;
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/ / /g;

	while($str =~ s/<p><(b|strong)>[0-9]+\. (.*?)<br ?\/?>(.*?)<\/p>//s){
		$d = {};
		$d->{'title'} = trimHTML(trimText($2));
		$txt = $3;


		@ps = split(/<p>/,$txt);
		$hours = "";
		for($p = 0; $p < @ps; $p++){
			if($ps[$p] =~ /Address: ?(.*)/){
				$d->{'address'} = trimHTML(trimText($1));
			}
			if($ps[$p] =~ /Opening time: ?(.*)/){
				$d->{'hours'} = parseOpeningHours({'_text'=>$1});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}
			if($ps[$p] =~ /Email:.*mailto:([^\"]*)\"/){
				$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Email: $1";
			}
			if($ps[$p] =~ /Telephone: ?(.*)/){
				$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Telephone: ".trimHTML($1);
			}
			if($ps[$p] =~ /Website Icon[^\>]+><a href="([^\"]*)"/){
				$d->{'url'} = $1;
			}
		}
		if($hours){
			$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		}

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
	my $str = shift;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s+/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
