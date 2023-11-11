#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
use Web::Scraper;
use Data::Dumper;
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
		process '.KcpHeO', "warmspaces[]" => scraper {
			process 'p', 'p[]' => 'TEXT';
		};
	};
	
	$res = $warmspaces->scrape($str);
	@warm = @{$res->{'warmspaces'}};
	$n = @warm;

	$places;

	for($i = 0; $i <= $n; $i++){
		$ps = @{$warm[$i]->{'p'}};
		if($ps > 2){
			$d = {};
			if($warm[$i]->{'p'}[0] =~ /^([^\,]+), (.*)$/){
				$id = $warm[$i]->{'p'}[0];
				if(!$places->{$id}){ $places->{$id} = {'other'=>[]}; }
				$places->{$id}{'title'} = $1;
				$places->{$id}{'address'} = $2;
				for($p = 1; $p < $ps; $p++){
					$warm[$i]->{'p'}[$p] =~ s/[\s\t]?(\x{200b}|\x{200B}|\x{a0})[\s\t]?/ /gi;
					push(@{$places->{$id}{'other'}},$warm[$i]->{'p'}[$p]);
				}
			}
		}
	}

	foreach $id (keys(%{$places})){
		$d = {};
		$d->{'title'} = $places->{$id}{'title'};
		$d->{'address'} = $places->{$id}{'address'};
		$n = @{$places->{$id}{'other'}};
		$hours = "";
		for($p = 0; $p < $n; $p++){
			if($places->{$id}{'other'}[$p]){
				if($places->{$id}{'other'}[$p] =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/i){
					$hours .= ($hours ? ". ":"").$places->{$id}{'other'}[$p];
				}else{
					$d->{'description'} .= ($d->{'description'} ? " ":"").$warm[$i]->{'p'}[$p];
				}
			}
		}
		if($hours){
			$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
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
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
