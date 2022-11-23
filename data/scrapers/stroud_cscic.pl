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

	$str =~ s/[\n\r]+/\n/s;

	@entries = ();

	if($str =~ /<div class="wp-block-button">(.*?)<\/article>/s){
		$str = $1;
		while($str =~ s/<p><strong>(.*?)<\/strong>(.*?)<\/p>(.*?)(<p><strong>|<\/div>|<h2>)/$4/s){
			$address = $1;
			$entry = $3;
			$address =~ s/^([^\,]+)\, ?//s;
			$d = {'title'=>$1,'address'=>trimText(parseText($address))};

			while($entry =~ s/<p>(.*?)<\/p>//){
				$p = $1;
				if($p =~ /Contact: (.*?)$/){
					$contact = $1;
					if($contact =~ /<a href="mailto:([^\"]+)"/){
						$d->{'contact'} = "Email: $1";
					}
					if($contact =~ /<a href="(http[^\"]+)">/){
						$d->{'url'} = $1;
					}
				}else{
					$d->{'description'} .= ($d->{'description'} ? ", ":"").$p;
				}
			}
			$day = "";
			while($entry =~ s/<tr>(.*?)<\/tr>//){
				$tr = $1;
				@td = ();
				while($tr =~ s/<td>(.*?)<\/td>//){
					push(@td,trimText(parseText($1)));
				}
				if($td[0]){ $day = $td[0]; }
				$d->{'hours'} .= ($d->{'hours'} ? "; ":"").parseText("$day $td[1]".($td[2] ? " ".$td[2]:""));
			}
			if($d->{'hours'}){
				$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}})
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

