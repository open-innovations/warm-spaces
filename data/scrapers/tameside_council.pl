#!/usr/bin/perl

use strict;
use warnings;
use lib "./";
use utf8;
use Data::Dumper;
use Web::Scraper;
require "lib.pl";
binmode STDOUT, 'utf8';

my ($file,$i,$d,@td,@lines,$str,$warmspaces,$res,@entries);

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
	$warmspaces = scraper {
		process '#main .infopage > table > tbody > tr', "warmspaces[]" => scraper {
			process 'td[valign="top"]', 'td[]' => 'HTML';
		};
	};
	$res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		# Check if we have an array
		if(ref($res->{'warmspaces'}[$i]{'td'}) eq "ARRAY"){
			@td = @{$res->{'warmspaces'}[$i]{'td'}};
		}else{
			@td = ();
		}

		$d = {};
		if(@td == 5){
			if($td[0] =~ /href="([^\"]+)"/){
				$d->{'url'} = $1;
				if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.tameside.gov.uk".$d->{'url'}; }
			}
			$d->{'title'} = trimHTML($td[0]);
			$d->{'address'} = trimHTML($td[1]);
			if($d->{'address'} =~ s/\.? ([0-9]{4,} ?[0-9]{3,8} ?[0-9]{3,8})//){
				$d->{'contact'} = "Tel: ".$1;
			}
			$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($td[2])});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
			$d->{'description'} = trimHTML($td[3]);

		}elsif(@td == 4){

			if($td[0] =~ s/<a href="([^\"]+)">(.*?)<\/a>//){
				$d->{'url'} = $1;
				$d->{'title'} = $2;
				if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.tameside.gov.uk".$d->{'url'}; }
				$d->{'address'} = trimHTML($td[0]);
			}

			if($d->{'address'} =~ s/\.? ([0-9]{4,} ?[0-9]{3,8} ?[0-9]{3,8})//){
				$d->{'contact'} = "Tel: ".$1;
			}

			$d->{'address'} =~ s/(^\, ?| ?\,$)//g;

			$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($td[1])});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }

			$d->{'description'} = trimHTML($td[2]);

		}

		if($d->{'title'}){
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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\,\s*//g;
	return $str;
}
