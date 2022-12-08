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

	# Replace nbsp
	$str =~ s/\&nbsp;/ /g;
	# Remove empty paragraphs first - the table has loads of them
	$str =~ s/<p> <\/p>//g;

	# Build a web scraper
	my $warmspaces = scraper {
		process 'div[class="global-container page-content"] table tbody tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
		};
	};

	my $res = $warmspaces->scrape( $str );

	@entries;

	# Loop over warmspaces processing the <li> values
	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		$td = @{$d->{'td'}};
		
		if($td == 4){
			if($d->{'td'}[0] =~ s/^<p><strong>(.*?)<\/strong>//){
				$d->{'title'} = $1;
			}
			$address = trimHTML($d->{'td'}[0]);
			if($address){ $d->{'address'} = $address; }

			if($d->{'td'}[1] =~ /^<p>(.*?)<\/p>/){
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($1)});
			}
			if($d->{'td'}[2] =~ /^<p>(.*?)<\/p>/){
				$d->{'description'} = trimHTML($1);
			}
			$d->{'td'}[3] = trimHTML($d->{'td'}[3]);
			if($d->{'td'}[3]){
				$d->{'contact'} = $d->{'td'}[3];
			}

			delete $d->{'td'};

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
	$str =~ s/<\/p>/; /g;	# Replace end of paragraphs with semi-colons
	$str =~ s/<br ?\/?>/, /g;	# Replace <br> with commas
	$str =~ s/<[^\>]+>//g;	# Remove any remaining tags
	$str =~ s/ {2,}/ /g;	# De-duplicate spaces
	return $str;
}
