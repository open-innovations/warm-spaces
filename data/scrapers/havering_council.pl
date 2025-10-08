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
	
	# Convert special characters
	$str =~ s/–/-/g;
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/’/\'/g;


	# Build a web scraper
	$warmspaces = scraper {
		process 'table tbody > tr', "tr[]" => scraper {
			process 'td', 'td[]', 'HTML';
		}
	};
	$pscraper = scraper {
		process 'p', "p[]" => 'TEXT';
	};

	my $res = $warmspaces->scrape( $str );

	for($r = 0; $r < @{$res->{'tr'}}; $r++){

		@cols = @{$res->{'tr'}[$r]{'td'}};
		
		if(@cols == 3){
			
			$d = {};

			# Loop over table columns
			for($c = 0; $c < @cols; $c++){
				if($cols[$c] !~ /^<p>/){
					$cols[$c] = "<p>".$cols[$c]."</p>";
				}
				$got = $pscraper->scrape( $cols[$c] );
				@ps = @{$got->{'p'}};
				if($c == 0){
					if($ps[0] =~ /([^\,]*)\, (.*)/){
						$d->{'title'} = $1;
						$d->{'address'} = $2;
					}else{
						$d->{'title'} = $ps[0];
					}
				}elsif($c==1){
					for($p = 0; $p < @ps; $p++){
						if($ps[$p] =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/i){
							$d->{'times'} .= ($d->{'hours'} ? "; ":"").$ps[$p];
						}else{
							$d->{'description'} .= ($d->{'description'} ? "; ":"").$ps[$p];
						}
					}
				}elsif($c==2){
					for($p = 0; $p < @ps; $p++){
						if($ps[$p] =~ /([0-9]{3,}\s?[0-9]{5,})/){
							$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Tel: ".$ps[$p];
						}elsif($ps[$p] =~ /^([^\s]+\@[^\s]+)$/){
							$d->{'contact'} .= ($d->{'contact'} ? " ":"")."Email: ".$ps[$p];
						}
					}
				}
			}
			if(defined($d->{'times'})){
				$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'times'}});
				delete $d->{'times'};
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

