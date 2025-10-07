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
		@ps = ();
		for($b = 0,$p = -1; $b < @bits; $b++){
			if($bits[$b] =~ /^<strong>/){
				$p++;
			}
			$ps[$p] .= ($ps[$p] ? " ":"").$bits[$b];
		}
		for($p = 0; $p < @ps; $p++){
			$ps[$p] =~ s/<br ?\/?>//g;
			$ps[$p] =~ s/<\/?span[^\>]*>//g;
			$ps[$p] =~ s/<strong[^\>]*>/ /g;
			$ps[$p] =~ s/<\/strong[^\>]*>/ /g;
			$ps[$p] =~ s/(^\s*|\s*$)//g;
		}

		for($p = 0; $p < @ps; $p++){
			if($ps[$p] =~ /^Location ?(.*)$/i){
				$d->{'address'} = trimHTML($1);
			}elsif($ps[$p] =~ /^Opening hours ?(.*)$/i){
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($1)});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}elsif($ps[$p] =~ /^Activity ?(.*)$/i){
				$d->{'description'} = trimHTML($1);
			}elsif($ps[$p] =~ /^Website.*href="([^\"]+)"/){
				$d->{'url'} = $1;
			}
			if($ps[$p] =~ s/^(Contact.*)<a href="mailto:([^\"]+)">.*?<\/a>/$1/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".trimText($2);
			}
			if($ps[$p] =~ /^Contact ?(.*)((\+[0-9]+)?\s*((\(0\)|0)[0-9]{2,})\s+(([0-9]{3,} ?[0-9]{3,})))/){
				$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Telephone: ".trimHTML($1)." ".trimText($2);
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
