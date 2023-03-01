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
		process '.govuk-table tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$row = $res->{'warmspaces'}[$i];
		@td = @{$row->{'td'}};

		if(@td == 3){
			$d = {};
			if($td[0] =~ s/<strong>(.*?)<\/strong><br ?\/>//g){
				$d->{'title'} = trimHTML($1);
			}
			$d->{'address'} = trimHTML($td[0]);
			$d->{'description'} = $td[1];
			if($td[2] =~ /<a href="([^\"]+)"/){
				$d->{'url'} = $1;
				if($d->{'url'} =~ /^\//){
					$d->{'url'} = "https://www.north-herts.gov.uk".$d->{'url'};
				}
				if($d->{'url'} =~ s/^mailto:(.*)//){
					delete $d->{'url'};
				}
			}
			if($td[2] =~ /([0-9\s]{8,})/){
				$d->{'contact'} = "Tel: ".$1;
			}
			$d->{'hours'} = parseOpeningHours({'_text'=>parseText($td[1])});
			push(@entries,makeJSON($d));
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