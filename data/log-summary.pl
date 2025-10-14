#!/usr/bin/perl

use warnings;
use strict;
my ($basedir,$lib);
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

my ($log,@ds,$data,@lines,$n,$str,$i,$d,$id,$name,$total,$geo,$seconds,$warn);

$log = {};

# Read config
$data = LoadFile($basedir.'data.yml');
@ds = @{$data->{'directories'}};
for($d = 0; $d < @ds; $d++){
	$id = getID($ds[$d]->{'title'});
	$log->{$id} = {};
	$log->{$id}{'config'} = $ds[$d];
}

# Process log files
$log = processLog((-e $basedir."build.log.old" ? $basedir."build.log.old" : $basedir."build.log"),"old",$log);
$log = processLog($basedir."build.log","new",$log);

# Make output
$str = "| Number | Name | Total | Geo-coded | Change | Warnings | Time (s) |\n";
$str .= "| --- | --- | --- | --- | --- | --- | --- |\n";
$n = 1;
foreach $id (sort{$log->{$a}{'n'} <=> $log->{$b}{'n'}}(keys(%{$log}))){
	$str .= "| $n | ".($log->{$id}{'config'}{'url'} ? "[$log->{$id}{'name'}]($log->{$id}{'config'}{'url'})" : "$log->{$id}{'name'}")." | $log->{$id}{'total'}{'new'} | $log->{$id}{'geo'}{'new'} | ".($log->{$id}{'geo'}{'new'} eq $log->{$id}{'geo'}{'old'} ? "-" : ($log->{$id}{'geo'}{'new'} > $log->{$id}{'geo'}{'old'} ? "▲":"▼"))." | $log->{$id}{'warn'} | $log->{$id}{'seconds'}{'new'} |\n";
	$n++;
}
print $str;



################
# SUBROUTINES
sub processLog {
	my $file = shift;
	my $typ = shift;
	my $log = shift;
	
	my ($i,$n,$name,$id);
	my @lines = getFileContents($file);

	for($i = 0; $i < @lines; $i++){

		$lines[$i] =~ s/[\n\r]//g;
		if($lines[$i] =~ /^([0-9]+): (.*) \(([^\)]+)\)/){
			$n = $1;
			$name = $2;
			$id = $3;

			$log->{$id}{'name'} = $name;
			$log->{$id}{'n'} = $n;
			$log->{$id}{'warn'} = '';
			
			if(!defined($log->{$id}{'geo'})){ $log->{$id}{'geo'} = {}; }
			if(!defined($log->{$id}{'total'})){ $log->{$id}{'total'} = {}; }
			if(!defined($log->{$id}{'seconds'})){ $log->{$id}{'seconds'} = {}; }
			if(!defined($log->{$id}{'geo'}{$typ})){ $log->{$id}{'geo'}{$typ} = ''; }
			if(!defined($log->{$id}{'total'}{$typ})){ $log->{$id}{'total'}{$typ} = ''; }
			if(!defined($log->{$id}{'seconds'}{$typ})){ $log->{$id}{'seconds'}{$typ} = ''; }

		}
		if($lines[$i] =~ /Added ([0-9]+) features \(([0-9]+) geocoded\)/){
			if($id){
				$log->{$id}{'total'}{$typ} = $1;
				$log->{$id}{'geo'}{$typ} = $2;
			}
		}
		if($lines[$i] =~ /Processed in ([0-9]+) seconds/){
			if($id){
				$log->{$id}{'seconds'}{$typ} = $1;
			}
		}
		if($lines[$i] =~ /WARNING: No JSON returned from scraper/ && $log->{$id}{'warn'} !~ /No JSON/){
			$log->{$id}{'warn'} .= ($log->{$id}{'warn'} ? "; ":"")."No JSON";
		}
		if($lines[$i] =~ /WARNING: No features found in web page./ && $log->{$id}{'warn'} !~ /No features/){
			$log->{$id}{'warn'} .= ($log->{$id}{'warn'} ? "; ":"")."No features";
		}
	}
	return $log;
}

sub getID {
	my $str = $_[0];
	$str = lc($str);
	$str =~ s/[^a-z0-9\-\_]/\_/g;
	return $str;
}
