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

	# Build a web scraper
	my $warmspaces = scraper {
		process 'div[class="Terratype"]', "warmspaces[]" => scraper {
			process '*', 'content' => 'HTML';
			process 'span[class="bold"]', 'title' => 'TEXT';
			process 'p', 'p' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$entry = $res->{'warmspaces'}[$i];

#print Dumper $entry;
		if($entry->{'title'}){
			$d = {'title'=>$entry->{'title'}};
			if($entry->{'content'} =~ /data-googlemapsv3="([^\"]+)"/){
				if($1 =~ /datum\%22\%3a\%22([^\%]+)\%2c([^\%]+)\%22/){
					$d->{'lat'} = $1;
					$d->{'lon'} = $2;
				}
			}
			if($entry->{'p'} =~ s/(.*)<br \/><br \/>//){
				@hours = split(/<br ?\/?>/,$1);
				for($h = 0; $h < @hours; $h++){
					$hours[$h] =~ s/^plus //;
					if($hours[$h] =~ /(.*): (.*)/){
						$d->{'hours'} .= ($d->{'hours'} ? "; " : "").$2." ".$1;
					}
				}
				if($d->{'hours'}){
					$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
					if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
				}
				$d->{'description'} = parseText($entry->{'p'});
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
