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
		process '.paragraph--type--localgov-accordion-pane .field--name-localgov-body-text', "warmspaces[]" => 'HTML';
	};
	my $res = $warmspaces->scrape( $str );
	my $n = @{$res->{'warmspaces'}};
	
	warning("\tMatched $n sections on page.\n");
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$str = $res->{'warmspaces'}[$i];

		while($str =~ s/<h4 id="([^\>]*)">(.*?)<\/h4>(.*?)(<h4|$)/$4/){
			$d = {};
			$d->{'title'} = $2;
			$html = $3;
			if($html =~ s/<p>(Open:)<\/p><ul>(.*?)<\/ul>// || $html =~ s/<p>(Open) ((Mon|Tue|Wed|Thu|Fri|Sat|Sun).*?)<\/p>//){
				$hours = $1." ".$2;
				$hours =~ s/<\/li>/; /g;
				$hours =~ s/<li>//g;
				$hours =~ s/; $//g;
				$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			}
			if($html =~ s/<p>Contact:<\/p><ul>(.*?)<\/ul>//){
				$contact = $1;
				$contact =~ s/<li>//g;
				@li = split(/<\/li>/,$contact);
				for($l = 0; $l < @li; $l++){
					if($li[$l] =~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/){
						$d->{'address'} = $li[$l];
					}
					if($li[$l] =~ /href="([^\"]*)"/){
						$d->{'url'} = $1;
					}
					if($li[$l] =~ /([0-9\s]{8,})/){
						$d->{'contact'} = "Tel: $1";
					}
				}
			}
			$html =~ s/<\/?ul>//g;
			$html =~ s/<\/li><li>/; /g;
			$html =~ s/<\/?li>//g;
			$html =~ s/<\/?p>/ /g;
			$html =~ s/(^ | $)//g;
			$html =~ s/\s+/ /g;
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

