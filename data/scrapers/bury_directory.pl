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
	
	$str =~ s/\&nbsp;/ /g;

	@entries;

	while($str =~ s/<section[^\>]*id="page-content"[^\>]*>(.*?)<\/section>//s){
		$content = $1;
		if($content =~ /<div class="mt-4 text-xl builder-p">(.*?)<\/div>/s){
			$content = $1;
			while($content =~ s/<p><strong><u>(.*?)<\/u><\/strong><\/p>(.*?)(<p><strong><u>)/$3/s){
				$d = {'title'=>$1};
				$ws = $2;
				if($ws =~ s/<p><strong>Address\:? *<\/strong>:? *(.*?)<\/p>//sg){ $d->{'address'} = $1; }
				if($ws =~ s/<p><strong>Offer\:? *<\/strong>:? *(.*?)<\/p>//sg){ $d->{'description'} = $1; }
				if($ws =~ s/<p><strong>Website\:? *<\/strong>:? *<a[^\>]*href="([^\"]+)"//sg){ $d->{'url'} = $1; }
				if($ws =~ s/<p><strong>(Opening days\/times|Opening days and times)\:? *<\/strong>:? *(.*?)(<p><strong>|$)/$2/sg){ $d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($2)}); }
				if($ws =~ s/<p><strong>Email\:?<\/strong>:? ?(.*?)<\/p>//sg){ $d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".trimHTML($1); }
				if($ws =~ s/<p><strong>Telephone\:?<\/strong>:? ?(.*?)<\/p>//sg){ $d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$1; }

				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }

				# Store the entry as JSON
				push(@entries,makeJSON($d,1));

			}
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
	$str =~ s/(<br ?\/?>|<\/p>)/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
