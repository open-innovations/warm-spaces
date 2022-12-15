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
		process 'div[class="mb-4 page-block-content"] p', "warmspaces[]" => 'HTML';
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$p = $res->{'warmspaces'}[$i];

		$p =~ s/<br \/><\//<\//g;
		$p =~ s/<\/span>/<br \/>/g;
		# Sometimes they split strong text up
		$p =~ s/<\/strong><strong>//g;
		$p =~ s/<\/strong><span><strong>//g;

		if($p =~ s/(^<span>|^)<strong>(.*?)<\/strong>//){
			$d = {};
			$d->{'title'} = trimHTML($2);
			if($d->{'title'} =~ /^([^\,]+)\, ?(.*)$/){
				$d->{'address'} = $2;
				$d->{'title'} = $1;
				# Fix Portsmouth postcodes using the wrong character
				$d->{'address'} =~ s/P0([0-9]{1,2} [0-9][A-Z]{2})/PO$1/g;
			}

			if($p =~ s/<br ?\/?>Contact:?\s?<a[^\>]*href="([^\"]*)"[^\>]*>(.*?)<\/a>//si){
				$d->{'url'} = $1;
				if($d->{'url'} =~ s/mailto://){
					$d->{'contact'} = "Email: ".trimHTML($d->{'url'});
					delete $d->{'url'};
				}
			}
			if($p =~ s/<br ?\/?>Tel:?\s?(.*?)(<br \/>|$)//si){
				$d->{'contact'} .= ($d->{'contact'} ? "; " : "")."Tel: ".trimHTML($1);
			}
			$hours = "";

			while($p =~ s/<br ?\/?>([^\>]*(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday).*?)(<br \/>|$)//si){
				$hours = $1;
			}
			if($hours){
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($hours)});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
				if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
			}
			$d->{'description'} = trimHTML($p);

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
	$str =~ s/(^\s+|\s+$)//g;
	return $str;
}
