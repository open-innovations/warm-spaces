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

	$str =~ s/[\n\r]//g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;


	if($str =~ /<h2><a id="Warm_welcome_community_spaces" .*?<\/h2>(.*?)<h2>/){
		$str = $1;
		while($str =~ s/<p>(.*?)<\/p><p>(.*?)<\/p><ul>(.*?)<\/ul>//){
			$a = $1;
			$b = $2;
			$c = $3;

			$d = {};
			if($a =~ /<a href="([^\"]*)">([^\<]+)<\/a>/){
				$d->{'title'} = $2;
				$d->{'url'} = $1;
			}
			$d->{'description'} = $b;
			if($c =~ /<li><strong>Address: ?<\/strong>([^\<]*?) ?\</){ $d->{'address'} = $1; }
			if($c =~ /<li><strong>Opening hours: ?<\/strong>([^\<]*?) ?\</){
				$d->{'hours'} = {'_text'=>$1};
				$d->{'hours'} = parseOpeningHours($d->{'hours'});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			}
			if($c =~ /<li><strong>Contact number: ?<\/strong>([^\<]*?) ?\</){ $d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Phone: ".$1; }
			if($c =~ /<li><strong>Email: ?<\/strong>([^\<]*?) ?\</){ $d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$1; }

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

