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
	
	if($str =~ /<h2 id="hub-locations-and-offers-2-0">Hub locations and offers<\/h2>(.*?)(<h2|<\/div)/s){
		$content = $1;
		while($content =~ s/<p><strong>(.*?)<\/strong>(.*?)<p><strong>/<p><strong>/s){
			$d = {'title'=>trimHTML($1)};
			$body = $2;
			$body =~ s/^<br \/>//;
			@lines = split(/<br \/>/,$body);
			$d->{'address'} = trimHTML($lines[0]);
			for($i = 1; $i < @lines; $i++){
				if($lines[$i] =~ /Email: (.*)/){
					$d->{'contact'} = "Email: ".trimHTML($1);
				}
				if($lines[$i] =~ /<a href="([^\"]*)">/){
					$d->{'url'} = $1;
					if($1 =~ /^mailto/){
						delete $d->{'url'};
					}
				}
				if($lines[$i] =~ /Opening times: (.*)/i){
					$d->{'hours'} = trimHTML($1);
					if($d->{'hours'}){
						$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
						if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
						if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
					}
				}
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
	$str =~ s/^\,\s*//g;
	return $str;
}
