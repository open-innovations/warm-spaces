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
		process '#main-page-content .placement-row-wrapper .type-droplet .content-item-inner', "warmspaces[]" => 'HTML';
	};
	my $res = $warmspaces->scrape( $str );

	my $entry = scraper {
		process '> h2', 'title' => 'TEXT';
		process 'label', 'label[]' => 'TEXT';
		process 'div.content', 'content[]' => 'HTML';
	};

	my %results;
	my %entries;
	
	
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$html = $res->{'warmspaces'}[$i];
		
		$html =~ /<h2 id="([^\"]+)"/;
		$name = $1;
		$html =~ s/<\!--.*?-->//gs;

		$entries = $entry->scrape( $html );

		for($j = 0; $j < @{$entries->{'label'}}; $j++){

			$day = $entries->{'label'}[$j];
			$content = $entries->{'content'}[$j];
			
			while($content =~ s/<h2>(.*?)<\/h2>(.*?)(<hr|$)//si){
				$title = $1;
				$bit = $2;

				$contact = "";
				$address = "";
				
				$title =~ s/<[^\>]+>//g;
				if($title =~ s/^(.*?) \- ([^\(]+?)( \(|$)/$1$3/){
					$title = $1;
					$hours = $day." ".$2;
				}
				$title =~ s/ \(Click here[^\)]*?\)//gi;

				if($bit =~ /<p><strong>Location:<\/strong><\/p><p>(.*?)<\/p>/){
					$address = $1;
				}
				if($bit =~ /<p><strong>Contact:<\/strong><\/p><p>(.*?)<\/p>/){
					$contact = $1;
					$contact =~ s/<[^\>]+>//g;
				}
				$key = $address;

				# If we don't already have this address
				if(!$results{$key}){ $results{$key} = {}; }

				if(!$results{$key}{'title'}){ $results{$key}{'title'} = $title; }
				if(!$results{$key}{'address'}){ $results{$key}{'address'} = $address; }
				if(!$results{$key}{'contact'}){ $results{$key}{'contact'} = $contact; }
				if($hours){
					$results{$key}{'hours'} .= ($results{$key}{'hours'} ? '; ' : '').$hours;
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

