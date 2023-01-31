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
	my $page = scraper {
		process '.pagecontent', "content" => 'HTML';
	};
	my $para = scraper {
		process 'p', "p[]" => 'HTML';
	};
	my $res = $page->scrape( $str );

	$str = $res->{'content'};
	$str =~ s/’/\'/g;

	while($str =~ s/<h3>(.*?)<\/h3>(.*?)(<h3>|$)/$3/){
		$content = $2;
		$d = {'title'=>$1};

		@p = @{$para->scrape( $content )->{'p'}};
		for($i = 0; $i < @p; $i++){
			if($p[$i] =~ /Address: (.*)/i){
				$d->{'address'} = $1;
			}
			if($p[$i] =~ /What['’]s on offer: (.*)/i){
				$d->{'description'} = $1;
			}
			if($p[$i] =~ /Website: <a href="([^\"]*)"[^\>]*>/i){
				$d->{'url'} = $1;
			}
			if($d->{'url'} && $p[$i] =~ /Facebook: <a href="([^\"]*)"[^\>]*>/i){
				$d->{'url'} = $1;
			}
			if($p[$i] =~ /Contact: (.*)/i){
				$d->{'contact'} = $1;
			}
			if($p[$i] =~ /Date\/Time: (.*)/i){
				$d->{'hours'} = parseOpeningHours({'_text'=>parseText($1)});
			}

		}

		push(@entries,makeJSON($d,1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

