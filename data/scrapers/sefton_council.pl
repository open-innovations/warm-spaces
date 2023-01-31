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
	my $ps = scraper {
		process '.page-content p', "p[]" => 'HTML';
	};
	my $ps = $ps->scrape( $str );
	
	$day = "";
	$org = "";
	$orgs = {};

	for($i = 0; $i < @{$ps->{'p'}}; $i++){
		
		$row = $ps->{'p'}[$i];
		if($row =~ /<strong>([^\<]+)/){
			$day = $1;
		}
		$row =~ s/<br ?\/?>//g;
		if($row =~ /Organisation: (.*)/i){
			$org = $1;
			if(!defined $orgs->{$org}){ $orgs->{$org} = {'title'=>$1}; }
		}
		if($row =~ /Address: (.*)/i){
			$orgs->{$org}{'address'} = $1;
		}
		if($row =~ /Phone number: (.*)/i){
			$orgs->{$org}{'contact'} = $1;
		}
		if($row =~ /Opening times: (.*)/i){
			$orgs->{$org}{'hours'} .= ($orgs->{$org}{'hours'} ? "; ":"").$day." ".$1;
		}
	}
	foreach $org (sort(keys(%{$orgs}))){
		$orgs->{$org}{'hours'} = parseOpeningHours({'_text'=>$orgs->{$org}{'hours'}});
		if(!$orgs->{$org}{'hours'}{'opening'}){ delete $orgs->{$org}{'hours'}{'opening'}; }
		push(@entries,makeJSON($orgs->{$org},1));
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
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}