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

	# Open the file
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	
	
	# Build a web scraper
	my $warmspaces = scraper {
		process '.item--article', "warmspaces[]" => scraper {
			process '.item__title', 'title' => 'TEXT';
			process 'a.item__link', 'url' => '@HREF';
		}
	};
	
	my $warmpage = scraper {
		process '.location-info__value--address', 'address' => 'HTML';
		process '.location-info__link--directions', 'dirs' => '@HREF';
	};
	
	my $res = $warmspaces->scrape($str);
	
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$d->{'title'} = trimText($d->{'title'});
		if($d->{'url'} =~ /^\//){
			$d->{'url'} = "https://swansea.gov.uk".$d->{'url'};
			# Get new page here
			$rfile = "raw/swansea_council-page$i.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving $d->{'url'} to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$d->{'url'}' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1'`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
			my $page = $warmpage->scrape($str);
			if($page->{'address'}){
				$d->{'address'} = $page->{'address'};
				$d->{'address'} =~ s/<\/p>/, /g;
				$d->{'address'} =~ s/<p>//g;
				$d->{'address'} =~ s/, $//g;
			}
			if($page->{'dirs'} =~ /dir\/\/([0-9\.\+\-]+),([0-9\.\+\-]+)/){
				$d->{'lat'} = $1+0;
				$d->{'lon'} = $2+0;
			}
			# Store the entry as JSON
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/^<[^\>]+>//g;	# Remove initial HTML tags
	$str =~ s/<\/p>/ /g;	# Replace end of paragraphs with semi-colons
	$str =~ s/<ul>/; /g;	# Replace start of list with space
	$str =~ s/<\/li>/; /g;	# Replace end of list item with semi-colons
	$str =~ s/<br ?\/?>/, /g;	# Replace <br> with commas
	$str =~ s/<[^\>]+>//g;	# Remove any remaining tags
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/ {2,}/ /g;	# De-duplicate spaces
	return $str;
}