#!/usr/bin/perl

use lib "./";
use utf8;
use Web::Scraper;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';


# Get the file to process
$file = $ARGV[0];

# If the file exists
if(-e $file){

	@entries;

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);

	$str =~ s/[\n\r]/ /g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	# Build a web scraper
	my $warmspaces = scraper {
		process '.scc-accordion-v2__content', "warmspaces[]" => 'HTML';
	};
	my $res = $warmspaces->scrape( $str );
	my $n = @{$res->{'warmspaces'}};
	
	warning("\tMatched $n sections on page.\n");
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$str = $res->{'warmspaces'}[$i];

		while($str =~ s/<h4>(.*?)<\/h4>(.*?)(<h4|$)/$4/){
			
			$d = {};
			$d->{'title'} = $1;
			$html = $2;
			if($html =~ s/<p>(Open:)<\/p><ul>(.*?)<\/ul>// || $html =~ s/<p>(Open) ((Mon|Tue|Wed|Thu|Fri|Sat|Sun).*?)<\/p>//){
				$hours = $1." ".$2;
				$hours =~ s/<\/li>/; /g;
				$hours =~ s/<li>//g;
				$hours =~ s/; $//g;
				$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			}
			if($html =~ s/<p>Address: (.*?)<\/p>//){
				$d->{'address'} = $1;
			}
			$html =~ s/<\/?ul>//g;
			$html =~ s/<\/li><li>/; /g;
			$html =~ s/<\/?li>//g;
			$html =~ s/<\/p>/. /g;
			$html =~ s/<p>//g;
			$html =~ s/<hr ?\/?>//g;
			$html =~ s/(^ | $)//g;
			$html =~ s/\s+/ /g;
			$html =~ s/\.+/\./g;
			$d->{'description'} = $html;
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

