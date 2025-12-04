#!/usr/bin/perl

use lib "./";
use utf8;
use MIME::Base64;
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

	if($str =~ /window.wpgmp.mapdata1 = "([^\"]*)"/){
		# The JSON has been base64 encoded so we need to decode it first
		$json = JSON::XS->new->decode(decode_base64($1));

		for($i = 0; $i < @{$json->{'places'}}; $i++){
			$ok = 0;
			for($j = 0; $j < @{$json->{'places'}[$i]{'categories'}}; $j++){
				if($json->{'places'}[$i]{'categories'}[$j]{'name'} eq "c-a-f-e"){
					$ok = 1;
				}
				if($json->{'places'}[$i]{'categories'}[$j]{'name'} eq "RCC visit"){
					$ok = 1;
				}
			}
			
			if($ok){
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
					if(!defined($d->{'hours'}{'opening'})){
						delete $d->{'hours'}{'opening'};
					}
				}
				if($json->{'places'}[$i]{'location'}{'extra_fields'}{'website'}){
					$d->{'url'} = $json->{'places'}[$i]{'location'}{'extra_fields'}{'website'};
				}
				if($json->{'places'}[$i]{'location'}{'extra_fields'}{'phone-1'}){
					$d->{'contact'} = "Tel: ".$json->{'places'}[$i]{'location'}{'extra_fields'}{'phone-1'};
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

