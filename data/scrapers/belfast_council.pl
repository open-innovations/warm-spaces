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

	# Build a web scraper
	my $warmspaces = scraper {
		process 'ul[class="content-items wysiwyg"] tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		}
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$area = $res->{'warmspaces'}[$i];
		if(@{$area->{'td'}} == 4){
			$d = {};
			$d->{'title'} = trimHTML($area->{'td'}[0]);
			if($area->{'td'}[0] =~ /<a href="([^\"]+)"/){ $d->{'url'} = $1; if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.belfastcity.gov.uk".$d->{'url'}; } }
			$d->{'hours'} = parseOpeningHours({'_text'=>$area->{'td'}[1].' '.$area->{'td'}[2]});
			if($area->{'td'}[3]){ $d->{'contact'} = "Tel: ".$area->{'td'}[3]; }
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}