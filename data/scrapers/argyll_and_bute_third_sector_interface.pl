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
		process 'td[class="wsite-multicol-col"] div[class="paragraph"]', "warmspaces[]" => scraper {
			process '*', 'content' => 'HTML';
			process 'em', 'em[]' => 'HTML';
			process 'strong', 'strong[]' => 'TEXT';
			process 'a', 'url' => '@HREF';
		}
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		
		$area = $res->{'warmspaces'}[$i];

		if($area->{'strong'}[0]){
			$d = {'title'=>$area->{'strong'}[0],'address'=>trimHTML($area->{'em'}[0])};
			
			while($area->{'content'} =~ s/<([^\>]+)>[^\<]+<\/[^\>]+>//g){ }
			$d->{'description'} = trimHTML($area->{'content'});
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'description'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
			

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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}