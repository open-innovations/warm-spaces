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

	if($str =~ /var dataCommunitySpaces = (.*)/s){
		$json = parseJSON($1);
	}else{
		error("\tNo JSON data found\n");
		return "";
	}

	@features = @{$json->{'features'}};

	for($f = 0; $f < @features; $f++){
		$d = {};
		$d->{'title'} = $features[$f]->{'properties'}{'popupContent'};
		$d->{'url'} = $features[$f]->{'properties'}{'url'};
		$d->{'lat'} = $features[$f]->{'geometry'}{'coordinates'}[1];
		$d->{'lon'} = $features[$f]->{'geometry'}{'coordinates'}[0];

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
