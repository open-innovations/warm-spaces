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

	#$str =~ s/[\n\r]/ /g;
#	$str =~ s/[\s]{2,}/ /g;
	$str =~ s/\&nbsp;/ /g;

	@entries = ();
#
	if($str =~ s/("places":\[.*\]\}\])//s){
		$json = JSON::XS->new->decode("{".$1."}");
		for($i = 0; $i < @{$json->{'places'}}; $i++){
			if($json->{'places'}[$i]{'categories'}[0]{'name'} eq "Warm Spaces"){
				$d = {
					'address'=>$json->{'places'}[$i]{'address'},
					'title'=>$json->{'places'}[$i]{'title'},
					'lat'=>$json->{'places'}[$i]{'location'}{'lat'},
					'lon'=>$json->{'places'}[$i]{'location'}{'lng'},
					'description'=>$json->{'places'}[$i]{'location'}{'extra_fields'}{'notes'}
				};
				if($json->{'places'}[$i]{'location'}{'extra_fields'}{'meetup-day'}){
					$d->{'hours'} = {'_text'=>$json->{'places'}[$i]{'location'}{'extra_fields'}{'meetup-day'}." ".$json->{'places'}[$i]{'location'}{'extra_fields'}{'meetup-time'}};
					$d->{'hours'} = parseOpeningHours($d->{'hours'});
				}
				if($json->{'places'}[$i]{'location'}{'extra_fields'}{'website'}){
					$d->{'url'} = $json->{'places'}[$i]{'location'}{'extra_fields'}{'website'};
				}
				if($json->{'places'}[$i]{'location'}{'extra_fields'}{'phone-1'}){
					$d->{'contact'} = "Phone:".$json->{'places'}[$i]{'location'}{'extra_fields'}{'phone-1'};
				}
				push(@entries,makeJSON($d,1));
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

