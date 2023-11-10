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
	
	$data = {
		'The Good Heart' => {'address'=>'7 Palmer Street, BA11 1DS'},
		'Frome Library' => {'address'=>'Justice Lane, BA11 1BE'},
		'Key Centre' => {'address'=>'Key Centre, BA11 5AJ'},
		'Cricket Club' => { 'address'=>'Cricket Club, BA11 2AH'},
		'Trinity Church' => {'address'=>'Trinity Church, BA11 3DE'},
		'The Bridge Café' => {'address'=>'43 Selwood Rd, BA11 3BS'},
		'Cheese & Grain' => {'address'=>'Cheese and Grain, BA11 1BE'},
		'Coffee #1' => {'address'=>'Coffee #1, BA11 1BS'}		
	};
	

	while($str =~ s/BEGIN:VEVENT(.*?)END:VEVENT//s){
		$d = {};
		$event = $1;
		if($event =~ /SUMMARY:([^\n\r]*)/){
			$place = $1;
			$d->{'title'} = $place;
			# Split the place by hyphens and then take the last place that we have an address for
			@parts = split(/ - /,$place);
			for($p = 0; $p < @parts; $p++){
				if($data->{$parts[$p]}{'address'}){
					$d->{'address'} = $data->{$parts[$p]}{'address'};
				}
			}			
		}
		# Work out the opening hours
		if($event =~ /RRULE:([^\n\r]*)/){
			$rule = $1;
			$s = "";
			$e = "";
			$sdate = "";
			$edate = "";
			if($event =~ /(DTSTART;TZID=Europe\/London:[0-9]{8}T)([0-9]{2})([0-9]{2})/){ $s = $2.":".$3; $sdate = $1.$2.$3; }
			if($event =~ /(DTEND;TZID=Europe\/London:[0-9]{8}T)([0-9]{2})([0-9]{2})/){ $e = $2.":".$3; $edate = $1.$2.$3; }

			if($s && $e && $rule =~ /FREQ=WEEKLY/){
				if($rule =~ /BYDAY=(.*?)(;|$)/){
					@days = split(",",$1);
					$hrs = "";
					for($i = 0; $i < @days; $i++){
						$days[$i] = ucfirst(lc($days[$i]));
						$hrs .= ($hrs ? "; ":"").$days[$i]." $s-$e";

					}
					$d->{'hours'} = {'_text'=>$rule."\n".$sdate."\n".$edate,'opening'=>$hrs};
				}
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}