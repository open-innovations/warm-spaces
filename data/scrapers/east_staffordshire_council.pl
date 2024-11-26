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

	# Build a web scraper for table rows
	my $warmspaces = scraper {
		process '.field--name-localgov-text table tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		}
	};

	$res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = {};
		if(defined($res->{'warmspaces'}[$i]{'td'})){
			$d->{'address'} = $res->{'warmspaces'}[$i]{'td'}[1];
			if($d->{'address'} =~ /^([^\,]*),/){
				$d->{'title'} = $1;
			}
			$d->{'hours'} = parseOpeningHours({'_text'=>trimList($res->{'warmspaces'}[$i]{'td'}[2])});
			push(@entries,makeJSON($d,1));
		}
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}


sub trimList {
	my $str = $_[0];
	$str =~ s/<\/li><li>/; /g;
	$str =~ s/<br ?\/?>/; /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/\; \; ?/\; /g;
	$str =~ s/^\; ?//g;
	$str =~ s/\; ?$//g;
	return $str;
}