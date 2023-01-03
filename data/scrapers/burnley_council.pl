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

	# Get the locations
	my $locations = scraper {
		process '.marker', 'points[]' => scraper {
			process '*', 'lat' => '@DATA-LAT';
			process '*', 'lon' => '@DATA-LNG';
			process 'h3', 'title' => 'TEXT';
			process 'a', 'id' => '@HREF';
		};
	};
	my $places = $locations->scrape($str);

	# Build a web scraper
	my $warmspaces = scraper {
		process '.warmItem', "warmspaces[]" => scraper {
			process '*', 'content' => 'HTML';
			process 'h3', 'title' => 'TEXT';
			process 'address', 'address' => 'HTML';
			process 'p', 'p[]' => 'HTML';
			process '*', 'id' => '@ID';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$entry = $res->{'warmspaces'}[$i];

		$d = {};
		$d->{'title'} = $entry->{'title'};
		$d->{'address'} = $entry->{'address'};

		for($p = 2; $p < @{$entry->{'p'}}; $p++){
			if($entry->{'p'}[$p] =~ /OPEN:<\/strong> ?(.*)/){
				$d->{'hours'} = parseOpeningHours({'_text'=>$1});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}else{
				$d->{'description'} .= ($d->{'description'} ? "<br />":"").$entry->{'p'}[$p];
			}
		}


		for($id = 0; $id < @{$places->{'points'}}; $id++){
			if($places->{'points'}[$id]->{'id'} eq "#".$entry->{'id'}){
				$d->{'lat'} = $places->{'points'}[$id]->{'lat'};
				$d->{'lon'} = $places->{'points'}[$id]->{'lon'};
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

sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
