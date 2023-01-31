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

	$str =~ s/^\xFE\xFF//;	# UTF-16be BOM - https://stackoverflow.com/questions/42449973/remove-utf-16-bom-from-string-with-perl
	$json = JSON::XS->new->decode($str);

	@warmspaces = @{$json->{'value'}{'pageItems'}};

	$n = @warmspaces;

	for($i = 0; $i < @warmspaces; $i++){
		
		$d = {};
		
		if($warmspaces[$i]{'website'}){
			$d->{'url'} = $warmspaces[$i]{'website'};
			if($d->{'url'} !~ /^http/){ $d->{'url'} = "https://".$d->{'url'}; }
		}
		
		if($warmspaces[$i]{'name'}){
			$d->{'title'} = $warmspaces[$i]{'name'};
		}
		if($warmspaces[$i]{'description'}){
			$d->{'description'} = $warmspaces[$i]{'description'};
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'description'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
		}
		if($warmspaces[$i]{'address'}){
			$d->{'address'} = $warmspaces[$i]{'address'};
		}
		if($warmspaces[$i]{'postcode'}){
			$d->{'address'} .= ($d->{'address'} ? ", ":"").$warmspaces[$i]{'postcode'};
		}
		if($warmspaces[$i]{'contactName'}){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"").$warmspaces[$i]{'contactName'};
		}
		if($warmspaces[$i]{'phone'}){
			$d->{'contact'} .= ($d->{'contact'} ? ", ":"").$warmspaces[$i]{'phone'};
		}
		if($warmspaces[$i]{'email'}){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"").$warmspaces[$i]{'email'};
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
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}