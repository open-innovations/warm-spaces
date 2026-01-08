#!/usr/bin/perl

use strict;
use warnings;
use lib "./";
use utf8;
use Data::Dumper;
use JSON::XS;
use POSIX qw(strftime);
use DateTime;
require "lib.pl";
binmode STDOUT, 'utf8';

# Get the file to process
my $file = $ARGV[0];


# If the file exists
if(-e $file){

	# Open the file
	open(FILE,"<:utf8",$file);
	my @lines = <FILE>;
	close(FILE);
	my $str = join("",@lines);

	my ($f,$d,@entries,$o,$date,$week);

	my $json = JSON::XS->new->decode($str);
	my @features = @{$json->{'Result'}};
	my $today = DateTime->now->strftime("%F");
	my $aweek = DateTime->now->add(days => 7)->strftime("%F");

	for($f = 0; $f < @features; $f++){
		$d = {};
		
		$d->{'title'} = $features[$f]->{'Name'};
		$d->{'address'} = $features[$f]->{'Address'};
		$d->{'description'} = $features[$f]->{'Description'};
		if($features[$f]->{'Phone'}){
			$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Tel: ".$features[$f]->{'Phone'};
		}
		if($features[$f]->{'Email'}){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$features[$f]->{'Email'};
		}

		if($features[$f]->{'Geolocation'} =~ /([0-9\.]+), ([-0-9\.]+)/){
			$d->{'lat'} = $1;
			$d->{'lon'} = $2;
		}

		if(defined($features[$f]->{'Occurrences'})){
			for($o = 0; $o < @{$features[$f]->{'Occurrences'}}; $o++){
				# Put dates in ISO8601
				if($features[$f]->{'Occurrences'}[$o] =~ /([0-9]{2})\/([0-9]{2})\/([0-9]{4})/){
					$features[$f]->{'Occurrences'}[$o] = $3."-".$2."-".$1;
				}
			}
			@{$features[$f]->{'Occurrences'}} = sort(@{$features[$f]->{'Occurrences'}});
			$d->{'hours'} = "";
			for($o = 0; $o < @{$features[$f]->{'Occurrences'}}; $o++){
				$date = $features[$f]->{'Occurrences'}[$o];
				if($date ge $today && $date lt $aweek){
					$d->{'hours'} .= ($d->{'hours'} ? "; ":"").formatDate($date, "%A")." ".formatTime($features[$f]->{'StartTime'})."-".formatTime($features[$f]->{'EndTime'});
				}
			}
			if($d->{'hours'} eq ""){
				delete $d->{'hours'};
			}else{
				$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			}
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

sub formatTime {
	my $m = shift;
	my $h = int($m / 60);
	$m -= $h*60;
	return sprintf("%02d",$h).":".sprintf("%02d",$m);
}

sub getDateTime {
	my $str = $_[0];
	my ($y,$m,$d);

	if($str =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})/){
		return DateTime->new(year=>$1,month=>$2+0,day=>$3+0,hour=>0,minute=>0,second=>0,time_zone=>DateTime::TimeZone::UTC->instance);
	}elsif($str =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})/){
		return DateTime->new(year=>$3,month=>$2+0,day=>$1+0,hour=>0,minute=>0,second=>0,time_zone=>DateTime::TimeZone::UTC->instance);
	}
	return DateTime->now;
}

sub formatDate {
	my $dt = shift;
	my $format = shift;
	if(ref($dt) eq ""){
		$dt = getDateTime($dt);
	}
	my $d = $dt->day;
	my $nth = "th";
	if($d == 1 || $d == 21 || $d == 31){ $nth = "st"; }
	elsif($d == 2 || $d == 22){ $nth = "nd"; }
	elsif($d == 3 || $d == 23){ $nth = "rd"; }
	$format =~ s/\%o/$nth/;
	return $dt->strftime($format);
}

