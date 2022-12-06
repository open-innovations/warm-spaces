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
	$warmspaces = scraper {
		process 'table tbody > tr', "tr[]" => scraper {
			process 'td', 'td[]', 'HTML';
		}
	};

	my $res = $warmspaces->scrape( $str );

	
	for($r = 0; $r < @{$res->{'tr'}}; $r++){

		if(@{$res->{'tr'}[$l]{'td'}} == 3){
			
			$d = {};
			if($res->{'tr'}[$r]{'td'}[0] =~ s/^(.*?)<br ?\/?> ?//){
				$d->{'title'} = $1;
				$d->{'address'} = $res->{'tr'}[$r]{'td'}[0];
				$d->{'address'} =~ s/<br ?\/?> ?/, /g;
				$d->{'description'} = $res->{'tr'}[$r]{'td'}[1];
				$h = parseOpeningHours({'_text'=>$res->{'tr'}[$r]{'td'}[1]});
				if($h->{'opening'}){
					$d->{'hours'} = $h;
				}
				$d->{'contact'} = $res->{'tr'}[$r]{'td'}[2];
				
				$d->{'contact'} =~ s/<\/?ul>//g;
				$d->{'contact'} =~ s/<\/li>/, /g;
				$d->{'contact'} =~ s/<li>//g;
				$d->{'contact'} =~ s/<a href="mailto:[^\"]+"[^\>]*>(.*?)<\/a>/$1/g;
				if($d->{'contact'} =~ s/<a href="([^\"]+)"[^\>]*>.*?<\/a>//g){
					$d->{'url'} = $1;
				}
				while($d->{'contact'} =~ s/\, $//g){}

			}
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

