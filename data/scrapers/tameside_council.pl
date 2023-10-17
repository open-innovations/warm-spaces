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
		process '.fullcontainer.pad20 table > tbody > tr', "warmspaces[]" => scraper {
			process 'td[bgcolor="fff2cc"]', 'td[]' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		@td = @{$res->{'warmspaces'}[$i]{'td'}};

		$d = {};
		if(@td == 1){
			$td[0] =~ s/<a href="([^\"]+)">([^\>]+)<\/a>//;
			$d->{'title'} = $2;
			$d->{'url'} = $1;
			$d->{'address'} = trimHTML($td[0]);
		}elsif(@td == 2){
			if(trimHTML($td[0]) ne "Library"){
				if($td[0] =~ s/<(strong|a)>(.*?)<\/(strong|a)>//){
					$d->{'title'} = trimHTML($2);
				}
				$td[0] =~ s/<\/?p>//g;
				$d->{'address'} = trimHTML($td[0]);
				$d->{'hours'} = $td[1];
			}
		}elsif(@td == 3){
			if(trimHTML($td[0]) ne "Library"){
				if($td[0] =~ s/<(strong|a)>(.*?)<\/(strong|a)>//){
					$d->{'title'} = trimHTML($2);
				}
				$d->{'address'} = trimHTML($td[0]);
				$d->{'hours'} = $td[1];
			}
		}elsif(@td == 4){
			if(trimHTML($td[0]) ne "Where"){
				if($td[0] =~ s/<(strong|a)>(.*?)<\/(strong|a)>//){
					$d->{'title'} = trimHTML($2);
				}
				if(!$d->{'title'} && $td[0] =~ s/(.*?)\, //){
					$d->{'title'} = trimHTML($1);
				}
				$d->{'address'} = trimHTML($td[0]);
				if($td[2] =~ /(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/i){
					$d->{'hours'} = trimHTML($td[2]);
				}else{
					$d->{'hours'} = $td[1].". ".trimHTML($td[2]);
				}
				$d->{'description'} = trimHTML($td[3]);
			}
		}


		if($d->{'hours'}){
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
		}
		if(!$d->{'address'}){ delete $d->{'address'}; }
		if(!$d->{'description'}){ delete $d->{'description'}; }


		if($d->{'title'}){
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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\,\s*//g;
	return $str;
}
