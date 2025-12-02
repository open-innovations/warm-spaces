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

	# Get pages
	while($str =~ s/<a href="([^\"]+)"><img [^\>]*class="alignnone wp//s){
		push(@pages,$1);
	}

	for($p = 0; $p < @pages; $p++){

		$url = $pages[$p];
		$rfile = $file;
		$rfile =~ s/\.html/-$p.html/;

		# Keep cached copy of individual URL
		$age = getFileAge($rfile);
		if($age >= 86400 || -s $rfile == 0){
			warning("\tSaving $url to <cyan>$rfile<none>\n");
			# For each entry we now need to get the sub page to find the location information
			`curl -s --insecure -L $args --compressed -o $rfile "$url"`;
		}
		open(FILE,"<:utf8",$rfile);
		@lines = <FILE>;
		close(FILE);
		$str = join("",@lines);
		
		while($str =~ s/<h3>🌡️ (.*?) – Warm Space<\/h3>(.*?)(<h3>|<\/div>)/$3/s){
			$title = trim($1);
			$desc = $2;

			$d = {};
			$d->{'title'} = trim($title);

			$desc =~ s/\<\/div>.*//g;

			if($desc =~ /&quot;centerLatitude&quot;:([0-9\.]+),&quot;centerLongitude&quot;:([-0-9\.]+),/){
				$d->{'lat'} = $1;
				$d->{'lon'} = $2;
			}

			if($desc =~ s/Address:<\/strong>(.*?)<\/p>//is){
				$address = $1;
				$d->{'address'} = trim($address);
				if($address =~ /\&quot;centerLatitude\&quot;:([0-9\.]+),\&quot;centerLongitude&quot;:([-0-9\.]+)/){
					$d->{'lat'} = $1;
					$d->{'lon'} = $2;
				}
			}

			$list = "";
			if($desc =~ s/Opening hours:.*?<ul>(.*?)<\/ul>//is){
				$d->{'hours'} = {'_text'=>trim($1)};
				$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
				$d->{'hours'} = parseOpeningHours($d->{'hours'});
			}

			if($desc =~ s/About:(.*?)<\/p>//is){
				$d->{'description'} = trim($1);
			}


			if($desc =~ s/Contact:(.*?)(<\/(li|p)>)/$2/is){
				$contact = $1;
				$contact =~ s/<\/?strong>//g;
				if($contact =~ /[0-9\s]{8,}/){
					$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".trim($contact);
				}
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


sub trim {
	my $str = shift;
	#$str =~ s/\n/<br \/>/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/^\n//g;
	return $str;
}