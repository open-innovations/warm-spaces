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
	while($str =~ s/<h4>.*?<\/h4>.*?<a href="([^\"]+)"><img//s){
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
		
		while($str =~ s/<h3>(.*?)<\/h3>.*?<ul>(.*?)<\/ul>//s){
			$d = {};
			$list = $2;
			$d->{'title'} = $1;
			$d->{'title'} = trim($d->{'title'});
			$list =~ s/\n?<li>//g;
			$list =~ s/\n$//g;
			@li = split(/<\/li>/,$list);

			for($i = 0; $i < @li; $i++){
				if($li[$i] =~ /<strong>Address:<\/strong> (.*)/){
					$d->{'address'} = $1;
				}elsif($li[$i] =~ /<strong>When:<\/strong> (.*)/){
					$d->{'hours'} = {'_text'=>$1};
					$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
					$d->{'hours'} = parseOpeningHours($d->{'hours'});
				}else{
					$d->{'description'} .= ($d->{'description'} ? ". ":"").$li[$i];
				}
			}
			$d->{'description'} = trim($d->{'description'});
			$d->{'description'} =~ s/\n/ /g;

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
	$str =~ s/<[^\>]+>//g;
	return $str;
}