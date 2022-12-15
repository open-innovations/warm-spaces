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
		process 'div[class="pcg-content-page"] table tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){
		@td = @{$res->{'warmspaces'}[$i]{'td'}};

		$d = {};
		if(@td == 4 && trimHTML($td[0]) ne "Library"){

			# General Warm Spaces
			$d->{'title'} = trimHTML($td[0]);
			$d->{'address'} = trimHTML($td[1]);
			# Keep the last paragraph of the "What's on offer" column
			$d->{'description'} = $td[2];
			$d->{'description'} =~ s/.*<p>(.*?)<\/p>$/$1/;
			$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($td[2])});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
			$d->{'contact'} = trimHTML($td[3]);

		}elsif(@td == 10){

			# Library Warm Spaces
			$d->{'title'} = trimHTML($td[0]);
			$d->{'address'} = trimHTML($td[1]);
			$d->{'hours'} = "";
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Sunday ".trimHTML($td[2]);
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Monday ".trimHTML($td[3]);
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Tuesday ".trimHTML($td[4]);
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Wednesday ".trimHTML($td[5]);
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Thursday ".trimHTML($td[6]);
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Friday ".trimHTML($td[7]);
			$d->{'hours'} .= ($d->{'hours'} ? "; " : "")."Saturday ".trimHTML($td[8]);
			$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($d->{'hours'})});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
			$d->{'contact'} = trimHTML($td[9]);

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

