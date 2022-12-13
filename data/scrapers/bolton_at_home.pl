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
		process 'div[class="content-item single-content content-wrapper"]', "warmspaces[]" => scraper {
			process 'div[class="content-wrapper-inner"]', 'div[]' => scraper {
				process 'h1', 'heading' => 'HTML';
				process 'label', 'label[]' => 'HTML';
				process 'div[class="content"]', 'content[]' => 'HTML';
			}
		};
	};
	my $res = $warmspaces->scrape( $str );


	my %results;

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$area = $res->{'warmspaces'}[$i]{'div'}[0];
		if($area->{'heading'}){
			for($j = 0; $j < @{$area->{'label'}}; $j++){
				if($area->{'label'}[$j] =~ /(Open .*)/){
					$day = $1;
					while($area->{'content'}[$j] =~ s/<h2><strong>(.*?) - (.*?)<\/strong><\/h2>(.*?)(<h2>|$)/$4/){
						$hours = $2;
						$content = $3;
						$desc = "$1 - $2";
						if($content =~ /<p><strong>Location:<\/strong><\/p><p>(.*?)<\/p>/){
							$address = $1;
						}
						if($content =~ /<p><strong>Contact:<\/strong><\/p><p>(.*?)<\/p>/){
							$contact = $1;
							$contact =~ s/<[^\>]+>//g;
						}
						$key = "$address";

						if(!$results{$key}){ $results{$key} = {}; }

						if($address =~ /^(.*?)\, /){
							$results{$key}{'title'} = $1;
						}
						
						$hours =~ s/^([^0-9]+?) - ?//g;
						
						$results{$key}{'hours'} .= ($results{$key}{'hours'} ? '; ' : '')."$day ".$hours;
						$results{$key}{'description'} .= ($results{$key}{'description'} ? "; " : "").$day.": ".$desc;
						$results{$key}{'address'} .= ($results{$key}{'address'} !~ /$address/ ? ($results{$key}{'address'} ? "; " : "").$address : "");;
						$results{$key}{'contact'} .= ($results{$key}{'contact'} !~ /$contact/ ? ($results{$key}{'contact'} ? "; " : "").$contact : "");
					}
				}
			}
		}
	}

	foreach $key (sort(keys(%results))){
		$results{$key}{'hours'} = parseOpeningHours({'_text'=>$results{$key}{'hours'}});
		push(@entries,makeJSON($results{$key},1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

