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

	if($str =~ /<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);

		%nodes = %{$json->{'props'}{'publishedData'}{'nodes'}};

		foreach $node (keys(%nodes)){
			if($nodes{$node}{'data'}{'geometries'}){
				$geometries = $nodes{$node}{'data'}{'geometries'};
#				print Dumper $nodes{$node}{'data'}{'geometries'};
			}
		}

		foreach $node (keys(%nodes)){
			if($nodes{$node}{'data'}{'places'}){
				@places = @{$nodes{$node}{'data'}{'places'}};
				for($p = 0; $p < @places; $p++){
					$fid = $nodes{$node}{'data'}{'places'}[$p]{'featureId'};
					$d = {};

					$d->{'lat'} = $geometries->{$fid}{'nodes'}[0]{'lat'}+0;
					$d->{'lon'} = $geometries->{$fid}{'nodes'}[0]{'long'}+0;

					$d->{'title'} = $nodes{$nodes{$node}{'data'}{'places'}[$p]{'title'}}{'data'}{'text'};
					for($c = 0; $c < @{$nodes{$node}{'data'}{'places'}[$p]{'contents'}}; $c++){
						if($nodes{$nodes{$node}{'data'}{'places'}[$p]{'contents'}[$c]}{'data'}{'link'}){
							$d->{'url'} = $nodes{$nodes{$node}{'data'}{'places'}[$p]{'contents'}[$c]}{'data'}{'link'};
						}
						if($nodes{$nodes{$node}{'data'}{'places'}[$p]{'contents'}[$c]}{'data'}{'text'} =~ /Facilities:(.*)/){
							$d->{'description'} = trimHTML($1);
						}
						if($nodes{$nodes{$node}{'data'}{'places'}[$p]{'contents'}[$c]}{'data'}{'text'} =~ /Contact Number:(.*)/){
							$d->{'contact'} = trimHTML($1);
						}
						if($nodes{$nodes{$node}{'data'}{'places'}[$p]{'contents'}[$c]}{'data'}{'text'} =~ /Address:(.*)/){
							$d->{'address'} = trimHTML($1);
						}
						if($nodes{$nodes{$node}{'data'}{'places'}[$p]{'contents'}[$c]}{'data'}{'text'} =~ /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(.*)/){
							$d->{'hours'} .= ($d->{'hours'} ? "; ":"").$1.$2;
						}
					}
					$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
					
					push(@entries,makeJSON($d,1));
				}
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
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
