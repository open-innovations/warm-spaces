#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';


$json = getJSON("tests.json");
%done = {};
@tests = ();

# Remove any duplicates
for($i = 0; $i < @{$json->{'tests'}}; $i++){
	if(!$done{$json->{'tests'}[$i]{'text'}}){
		$done{$json->{'tests'}[$i]{'text'}} = 1;
		push(@tests,$json->{'tests'}[$i]);
	}
}

# Loop over the tests and check if they pass
my $n = @tests;
my $ngood = 0;
my $nbad = 0;
my $state = 0;
for($i = 0; $i < $n; $i++){
	$d = parseOpeningHours({'_text'=>$tests[$i]{'text'}});

	$state = ($tests[$i]{'good'} ? ($d->{'opening'} eq $tests[$i]{'good'} ? 'green':'red') : 'none');

	msg("<cyan>Test ".($i+1)."<none>: <$state>".($state eq "green" ? "[PASS]":"[FAIL]")."<none> \"$tests[$i]{'text'}\"\n");

	if($state ne "green"){
		msg("  Output: <$state>\"$d->{'opening'}\"<none>\n");
		msg("  Ideal:  <$state>\"$tests[$i]{'good'}\"<none>\n");
		$nbad++;
	}else{
		$ngood++;
	}
}

# Print the results
print "\n";
if($ngood > 0){ msg("<green>[PASS]:<none> $ngood test".($ngood != 1 ? "s":"")."\n"); }
if($nbad > 0){ msg("<red>[FAIL]:<none> $nbad test".($nbad != 1 ? "s":"")."\n"); }