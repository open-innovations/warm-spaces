#!/usr/bin/perl
my $basedir;
BEGIN {
	$basedir = $0;
	$basedir =~ s/[^\/]*$//g;
	if(!$basedir){ $basedir = "./"; }
	$lib = $basedir."";
}
use lib $lib;
use strict;
use warnings;
use Data::Dumper;
use POSIX qw(strftime);
use JSON::XS;
use OpenInnovations::Tiler;
require "lib.pl";


my $json = getJSON("places.json");

makeTiles($json,$ARGV[0]);



sub makeTiles {
	
	my $json = shift;
	my $zoom = shift;

	my ($str,$filegeo,$coder,$tiler,$dir,$f,@zooms,$z,%tiles,$x,$y,$zdir,$fh,$dh,$filename,@features,$prop);

	$dir = ("tiles");
	@zooms = split(/[\:\;]/,$zoom||"12");

	if(!-d $dir){
		`mkdir $dir`;
	}


	for($z = 0; $z < @zooms; $z++){
		$zdir = "$dir/$zooms[$z]/";
		if(!-d $zdir){
			`mkdir $zdir`;
		}else{
			print "Removing $zdir\n";
			`rm -Rf $zdir`;
			`mkdir $zdir`;
		}
	}

	my ($line,$jsonbit,$t,$file,$feature,$dp,$maxsize,$size);

	$coder = JSON::XS->new->utf8->canonical(1)->allow_nonref(1);

	$tiler = OpenInnovations::Tiler->new();
	@features = @{$json};

	for($f = 0; $f < @features; $f++){
		if($features[$f]->{'lat'} && $features[$f]->{'lon'}){
			$jsonbit = {'type'=>'Feature'};
			$jsonbit->{'geometry'} = {'type'=>'Point','coordinates'=>[sprintf("%0.5f",$features[$f]->{'lon'}),sprintf("%0.5f",$features[$f]->{'lat'})]};
			$jsonbit->{'properties'} = $features[$f];
			$jsonbit->{'properties'}{'hours'} = $features[$f]->{'hours'}{'opening'};
			if(!$jsonbit->{'properties'}{'hours'}){ delete $jsonbit->{'properties'}{'hours'}; }
			delete $jsonbit->{'properties'}{'lat'};
			delete $jsonbit->{'properties'}{'lon'};

			$feature = $coder->encode($jsonbit);
			# Make coordinates into numbers rather than strings
			$feature =~ s/\"([\-\+]?[0-9]+\.[0-9]+)\"/$1/g;

			for($z = 0; $z < @zooms; $z++){
				$zoom = $zooms[$z]||12;
				($x,$y) = $tiler->project($jsonbit->{'geometry'}->{'coordinates'}[1],$jsonbit->{'geometry'}->{'coordinates'}[0],$zoom);
				if(!-d "$dir/$zoom/$x/"){
					`mkdir $dir/$zoom/$x/`;
				}
				$file = "$dir/$zoom/$x/$y.geojson";
				$tiles{$file} = 1;
				if(!-e $file || -s $file == 0){
					open($fh,">",$file)||error('No file '.$file);
					print $fh "{\n\t\"type\": \"FeatureCollection\",\n\t\"features\": [\n";
				}else{
					open($fh,">>",$file)||error('No file '.$file);
					print $fh ",\n";
				}
				print $fh "\t\t".$feature;
				close($fh);

			}
		}
	}
	$maxsize = 0;
	foreach $file (sort(keys(%tiles))){
		open(FILE,">>",$file);
		print FILE "\n\t\]\n\}\n";
		close(FILE);
		$size = -s $file;
		if($size > $maxsize){
			print "Largest file $file: $size\n";
			$maxsize = $size;
		}
	}
	exit;
}
