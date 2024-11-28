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
	$str =~ s/\&nbsp;/ /gs;
	$str =~ s/\&apos;/\'/gs;
	
	my $pageparser = scraper {
		process '.multi_part_section', 'days[]' => scraper {
			process 'h2', 'day' => 'TEXT';
			process 'table tbody tr', 'tr[]' => scraper {
				process 'td', 'td[]' => 'HTML';
			}
		};
	};
	
	@days = @{$pageparser->scrape( $str )->{'days'}};
	
	my %places;

	for($d = 0; $d < @days; $d++){
		$days[$d]->{'day'} =~ s/s$//g;
		for($r = 0; $r < @{$days[$d]->{'tr'}}; $r++){
			$address = $days[$d]->{'tr'}[$r]{'td'}[0];
			$title = "";
			if($address =~ /^([^\,]*)\,/){
				$title = $1;
				if(!defined($places{$title})){
					$places{$title} = {'title'=>$title};
				}
				$places{$title}{'address'} = $address;
				if($days[$d]->{'tr'}[$r]{'td'}[1]){
					$days[$d]->{'tr'}[$r]{'td'}[1] = lcfirst( $days[$d]->{'tr'}[$r]{'td'}[1]);
					$places{$title}{'hours'} .= ($places{$title}{'hours'} ? "; ":"").$days[$d]->{'day'}." ".$days[$d]->{'tr'}[$r]{'td'}[1];
				}
				if($days[$d]->{'tr'}[$r]{'td'}[2]){
					$txt = trimHTML($days[$d]->{'tr'}[$r]{'td'}[2]);
					$places{$title}{'description'} .= ($places{$title}{'description'} ? ($places{$title}{'description'} !~ /\.$/ ? ".":"")." ":"").$days[$d]->{'day'}.": ".$txt;
					if($days[$d]->{'tr'}[$r]{'td'}[2] =~ /href="([^\"]+)"/){
						$places{$title}{'url'} = $1;
					}
				}
			}
		}
	}
	foreach $title (sort(keys(%places))){
		$d = $places{$title};
		if($d->{'hours'}){
			$d->{'hours'} = parseOpeningHours({'_text'=>parseText($d->{'hours'})});
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
