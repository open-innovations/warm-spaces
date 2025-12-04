#!/usr/bin/perl

use lib "./";
use utf8;
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
	

	$json = JSON::XS->new->decode($str);

	push(@content,@{$json->{'content'}});
	$p = $json->{'meta'}{'current_page'};
	while($json->{'links'}{'next'}){
		$url = $json->{'links'}{'next'}."&per_page=20&text=&proximity=4&postcode=&taxonomy_id=vCSE:19&minimum_age=&maximum_age=&facility=&language=&team=vcse&service_area=";
		$rfile = "raw/west-northamptonshire-".($json->{'meta'}{'current_page'}).".html";
		# Keep cached copy of individual URL
		$age = getFileAge($rfile);
		if($age >= 86400 || -s $rfile == 0){
			warning("\tSaving <blue>$url<none> to <cyan>$rfile<none>\n");
			# For each entry we now need to get the sub page to find the location information
			`curl '$url' -o $rfile -s --insecure -L --compressed -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Upgrade-Insecure-Requests: 1'`;
		}
		open(FILE,"<:utf8",$rfile);
		@lines = <FILE>;
		close(FILE);
		$str = join("",@lines);
		$json = JSON::XS->new->decode($str);
		push(@content,@{$json->{'content'}});
	}

	@addressparts = ('address_1','city','state_province','postal_code');

	for($i = 0; $i < @content; $i++){
		$d = {};
		$d->{'title'} = trimHTML($content[$i]{'name'});
		$d->{'url'} = $content[$i]{'url'};
		$d->{'description'} = trimHTML($content[$i]{'description'});
		if($content[$i]{'email'}){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Email: ".$content[$i]{'email'};
		}
		for($j = 0; $j < @{$content[$i]{'contacts'}}; $j++){
			$d->{'contact'} .= ($d->{'contact'} ? "; ":"")."Tel: ".$content[$i]{'contacts'}[0]{'phones'}[0]{'number'};
		}
		for($a = 0; $a < @addressparts; $a++){
			if($content[$i]{'service_at_locations'}[0]{'physical_addresses'}[0]{$addressparts[$a]}){
				$d->{'address'} .= ($d->{'address'} ? ", ":"").$content[$i]{'service_at_locations'}[0]{'physical_addresses'}[0]{$addressparts[$a]};
			}
		}
		if($content[$i]{'service_at_locations'}[0]{'latitude'}){
			$d->{'lat'} = $content[$i]{'service_at_locations'}[0]{'latitude'};
		}
		if($content[$i]{'service_at_locations'}[0]{'longitude'}){
			$d->{'lon'} = $content[$i]{'service_at_locations'}[0]{'longitude'};
		}
		for($j = 0; $j < @{$content[$i]{'regular_schedules'}}; $j++){
			$d->{'hours'} .= ($d->{'hours'} ? "; ":"").$content[$i]{'regular_schedules'}[$j]{'weekday'}." ".$content[$i]{'regular_schedules'}[$j]{'opens_at'}."-".$content[$i]{'regular_schedules'}[$j]{'closes_at'};
		}
		if($d->{'hours'}){
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		}
		
		# Store the entry as JSON
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}