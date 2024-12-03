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
		process 'table[class="table table-bordered"] > tbody > tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		@td = @{$res->{'warmspaces'}[$i]{'td'}};

		$address = $td[1];
		$address =~ s/\&apos;/\'/gs;
		if($address =~ s/^(.*?) ?(<br ?\/?>|\,|\t)(.*)$//){
			$d->{'title'} = trimHTML($1);
			$address = $3;
			if($address =~ s/<p>Contact email:\s?(.*?)<\/p>//si){
				$d->{'contact'} = trimHTML($1);
			}
			$d->{'address'} = trimHTML($address);
			$d->{'address'} =~ s/ ,/,/g;
			$d->{'address'} =~ s/,+/,/g;
		}
		$td[0] =~ s/<\/p><p>/; /g;
		$td[0] =~ s/<br ?\/?>/ /g;
		$td[0] = trimHTML($td[0]);
		$td[0] =~ s/day\&apos;s/days/gs;
		$d->{'hours'} = parseOpeningHours({'_text'=>$td[0]});
		if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
		$d->{'description'} = trimHTML($td[2]);

		delete $d->{'td'};

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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\, //g;
	return $str;
}
