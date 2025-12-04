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
	
	$str =~ s/[\n\r]/ /g;
	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;
	
	
	# Build a web scraper
	$warmspaces = scraper {
		process 'ul.mt-8.grid li a', "warmspaces[]" => '@HREF';
	};
	$warmspace = scraper {
		process '#ContentTop', 'title' => 'TEXT';
		process '.max-w-4xl', 'p' => 'HTML';
	};

	@pages = @{$warmspaces->scrape($str)->{'warmspaces'}};
	
	for($i = 0; $i < @pages; $i++){
		$url = $pages[$i];
		$rfile = "raw/torbay-$i.html";

		# Keep cached copy of individual URL
		$age = getFileAge($rfile);
		if($age >= 86400 || -s $rfile == 0){
			warning("\tSaving <blue>".($d->{'url'}||"")."<none> to <cyan>".($rfile||"")."<none>\n");
			# For each entry we now need to get the sub page to find the location information
			`curl '$url' -o $rfile -s --insecure --connect-timeout 10 -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
		}
		open(FILE,"<:utf8",$rfile);
		@lines = <FILE>;
		close(FILE);
		$html = join("",@lines);
		
		$d = $warmspace->scrape($html);
		$d->{'title'} = trimHTML($d->{'title'});
		if($d->{'p'} =~ s/<p><strong>Address:?<\/strong> ?\-? ?(.*?)<\/p>//is){
			$d->{'address'} = trimHTML($1);
		}
		if($d->{'p'} =~ s/<p><strong>Telephone:?<\/strong> ?(.*?)<\/p>//is){
			$d->{'contact'} = ($d->{'contact'} ? "; ":"")."Tel: ".trimHTML($1);
		}
		$d->{'hours'} = {'_text'=>''};
		while($d->{'p'} =~ s/<p><strong>([^\<]*Opening hours:?[^\<]*)<\/strong>(.*?)<p><strong>/<p><strong>/is){
			$d->{'hours'}{'_text'} .= ($d->{'hours'}{'_text'} ? "; ":"").$1.": ".trimHTML($2);
		}
		if($d->{'hours'}{'_text'}){
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		}else{
			delete $d->{'hours'};
		}
		$d->{'description'} = trimHTML($d->{'p'});
		delete $d->{'p'};

		push(@entries,makeJSON($d,1));
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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\,\s*//g;
	return $str;
}