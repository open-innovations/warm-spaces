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

	# Get the locations
	my $warmspaces = scraper {
		process '.accordion .accordion-title', 'titles[]' => 'TEXT';
		process '.accordion .accordion-panel', 'content[]' => scraper {
			process 'p', 'p[]' => 'HTML';
		};
	};
	
	
	my $res = $warmspaces->scrape($str);
	for($i = 0; $i < @{$res->{'titles'}}; $i++){


		$d = {};
		$d->{'title'} = trimText($res->{'titles'}[$i]);

		@bits = @{$res->{'content'}[$i]{'p'}};
		for($b = 0; $b < @bits; $b++){
			if($bits[$b] =~ /Location/ && $b+1 < @bits){
				$d->{'address'} = $bits[$b+1];
			}
			if($bits[$b] =~ /<strong>Opening hours<\/strong>(.*)$/i){
				$bits[$b] = trimHTML($1);
				$d->{'hours'} = parseOpeningHours({'_text'=>$bits[$b]});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}
			if($bits[$b] =~ /<strong>Activity<\/strong>(.*)$/i){
				$d->{'description'} = trimHTML($1);
			}
			if($bits[$b] =~ /Website.*href="([^\"]+)"/){
				$d->{'url'} = $1;
			}
			if($bits[$b] =~ /Contact.*href="mailto:([^\"]+)"/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".trimText($1);
			}
			if($bits[$b] =~ /Contact.*((\+[0-9]+)?\s*((\(0\)|0)[0-9]{2,})\s+(([0-9]{3,} ?[0-9]{3,})))/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".trimText($1);
			}
			
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
	$str =~ s/^<br ?\/?>//;
	$str =~ s/(<br ?\/?>|<p>)/; /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
