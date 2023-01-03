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
		process 'div[class="service-results__item"]', "warmspaces[]" => scraper {
			process 'a[class="service__results--heading"]', 'title' => 'TEXT';
			process 'a[class="service__results--heading"]', 'url' => '@HREF';
			process 'div[class="service-results__summary"]', 'description' => 'TEXT';
			process '.nvp--service-location .nvp__value', 'address' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];

		$d->{'address'} = trimHTML($d->{'address'});
		$d->{'title'} = trimHTML($d->{'title'});
		$d->{'description'} = trimHTML($d->{'description'});

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
	$str =~ s/ ?(<br ?\/?>|<p>) ?/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
