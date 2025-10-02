#!/usr/bin/perl

use lib "./";
use utf8;
use Web::Scraper;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';

# Fix for Web::Scraper not finding <meta> tags
use HTML::Tagset;
for (qw/ link meta /) {
    $HTML::Tagset::isHeadElement{$_}       = 0;
    $HTML::Tagset::isHeadOrBodyElement{$_} = 1;
}


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
	
	
	# Build a web scraper
	my $warmspaces = scraper {
		process 'div.service-summary-left', "warmspaces[]" => scraper {
			process 'a.service-name', 'title' => 'TEXT';
			process 'meta[itemprop=latitude]', 'lat' => '@content';
			process 'meta[itemprop=longitude]', 'lon' => '@content';
			process 'span[itemprop=streetAddress]', 'address' => 'TEXT';
			process 'span[itemprop=postalCode]', 'postcode' => 'TEXT';
			process '.bem-search-result-item__contact-item', 'contacts[]' => 'TEXT';
		}
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		
		if(defined($d->{'contacts'})){
			$d->{'contact'} = "";
			for($c = 0; $c < @{$d->{'contacts'}}; $c++){
				$d->{'contacts'}[$c] =~ s/(^\s+|\s+$)//g;
				$d->{'contacts'}[$c] =~ s/\s+/ /g;
				$d->{'contact'} .= ($d->{'contact'} ? " ":"").$d->{'contacts'}[$c];
			}
			delete $d->{'contacts'};
		}
		if($d->{'postcode'}){
			$d->{'address'} .= " ".$d->{'postcode'};
			delete $d->{'postcode'};
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

