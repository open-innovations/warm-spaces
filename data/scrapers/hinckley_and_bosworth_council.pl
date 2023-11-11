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
	my $pages = scraper {
		process '.boxed__list a.list__link', "a[]" => '@HREF';
	};


	# Build a web scraper
	my $ul = scraper {
		process 'ul > li', "li[]" => 'HTML';
	};



	$pages = $pages->scrape($str);
	
	for($a = 0; $a < @{$pages->{'a'}}; $a++){

		$url = $pages->{'a'}[$a];
		$rfile = "raw/hinckley_and_bosworth_council_".($a+1).".html";
		# Keep cached copy of individual URL
		$age = getFileAge($rfile);
		if($age >= 86400 || -s $rfile == 0){
			warning("\tSaving <green>$url<none> to <cyan>$rfile<none>\n");
			# For each entry we now need to get the sub page to find the location information
			`curl '$url' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
		}
		open(FILE,"<:utf8",$rfile);
		@lines = <FILE>;
		close(FILE);
		$str = join("",@lines);
		

		while($str =~ s/<h4>([^\<]*)<\/h4>(.*?)<h4>/<h4>/s){
			$d = {'title'=>$1};
			$content = $2;
			
			$res = $ul->scrape($content);
			@li = @{$res->{'li'}};
			for($i = 0; $i < @li; $i++){
				if($li[$i] =~ /Location: (.*)/){
					$d->{'address'} = trimHTML($1);
				}
				if($li[$i] =~ /Warm welcome times: (.*)/){
					$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($1)});
				}
				if($li[$i] =~ /What[^\?]*s on offer\? (.*)/){
					$d->{'description'} = trimHTML($1);
					$d->{'description'} =~ s/;( |$)/.$1/g;
				}
				if($li[$i] =~ /a href="([^\"]*)"/){
					$d->{'url'} = $1;
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<\/li>/; /g;
	$str =~ s/\;$//g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}