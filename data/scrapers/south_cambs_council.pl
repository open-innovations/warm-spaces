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

	my $pageparser = scraper {
		process 'table.table-bordered tr', 'tr[]' => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};
	
	my $res = $pageparser->scrape( $str );

	for($r = 0; $r < @{$res->{'tr'}}; $r++){
		$d = {};
		$d->{'title'} = parseText($res->{'tr'}[$r]{'td'}[0]);
		$d->{'address'} = trimHTML($res->{'tr'}[$r]{'td'}[1]);
		$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($res->{'tr'}[$r]{'td'}[2])." ".trimHTML($res->{'tr'}[$r]{'td'}[3])});
		
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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/^\, //g;
	$str =~ s/ \, /, /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
