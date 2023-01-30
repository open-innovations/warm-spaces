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

	# Get the locations
	my $warmspaces = scraper {
		process 'li.accordion-item', 'warmspaces[]' => scraper {
			process '.accordion-item__title', 'title' => 'TEXT';
			process '.accordion-item__description p', 'content' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape($str);

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$entry = $res->{'warmspaces'}[$i];

		$d = {};
		$d->{'title'} = trimHTML($entry->{'title'});

		@bits = split(/<br ?\/?>/,$entry->{'content'});
		$title = "";
		for($b = 0; $b < @bits; $b++){
			if($bits[$b] =~ /(.*): (.*)/){
				$title = $1;
				$arg = $2;
			}else{
				$arg = $bits[$b];
			}
			if($title =~ /Opening hours/i){
				$d->{'hours'} .= ($d->{'hours'} ? "; ":"").$arg;
			}
			if($title =~ /Contact/i){
				$arg =~ s/<[^\>]+>//g;
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"").$arg;
			}
			if($title =~ /Website/i){
				if($arg =~ /<a href="([^\"]+)"[^\>]*>/){
					$d->{'url'} = $1;
				}
			}
			if($title =~ /Activity/i){
				$d->{'description'} .= ($d->{'description'} ? " ":"").$arg;
			}
		}
		if($d->{'hours'}){
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
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

sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
