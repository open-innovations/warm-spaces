#!/usr/bin/perl

my $basedir;
BEGIN {
	$basedir = $0;
	$basedir =~ s/[^\/]*$//g;
	if(!$basedir){ $basedir = "./"; }
	$lib = $basedir."";
}
use lib $lib;
use utf8;
use Data::Dumper;
use YAML::XS 'LoadFile';
require "lib.pl";

my $data = LoadFile($basedir.'data.yml');
my @ds = @{$data->{'directories'}};
my $directories = {};
for($d = 0; $d < @ds; $d++){
	$directories->{getID($ds[$d]->{'title'})} = $ds[$d];
}

@lines = getFileContents($basedir."build.log");

$n = 0;
$str = "| Number | Name | Total | Geo-coded | Warnings | Time (s) |\n";
$str .= "| --- | --- | --- | --- | --- | --- |\n";
for($i = 0; $i < @lines; $i++){
	
	$lines[$i] =~ s/[\n\r]//g;
	if($lines[$i] =~ /^([0-9]+): (.*) \(([^\)]+)\)/){
		if($n > 0){
			$str .= "| $n | ".($directories->{$id}{'url'} ? "[$name]($directories->{$id}{'url'})" : "$name")." | $total | $geo | $warn | $seconds |\n";
		}
		$n = $1;
		$name = $2;
		$id = $3;
		$total = "";
		$geo = "";
		$seconds = "";
		$warn = "";
	}
	if($lines[$i] =~ /Added ([0-9]+) features \(([0-9]+) geocoded\)/){
		$total = $1;
		$geo = $2;
	}
	if($lines[$i] =~ /Processed in ([0-9]+) seconds/){
		$seconds = $1;
	}
	if($lines[$i] =~ /WARNING: No JSON returned from scraper/ && $warn !~ /No JSON/){
		$warn .= ($warn ? "; ":"")."No JSON";
	}
	if($lines[$i] =~ /WARNING: No features found in web page./ && $warn !~ /No features/){
		$warn .= ($warn ? "; ":"")."No features";
	}
}

print $str;



################
# SUBROUTINES
sub getID {
	my $str = $_[0];
	$str = lc($str);
	$str =~ s/[^a-z0-9\-\_]/\_/g;
	return $str;
}
