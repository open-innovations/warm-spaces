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

	if($str =~ /window.REDUX_DATA = (.*?)<\/script>/){
		$str = $1;
		if(!$str){ $str = "{}"; }
		$json = JSON::XS->new->decode($str);
	
		my $rows = scraper {
			process 'tr', 'warmspaces[]' => scraper {
				process 'td', 'td[]' => 'HTML';
			}
		};

		$places;
		@entries;
		
		for($t = 0; $t < @{$json->{'routing'}{'entry'}{'mainContent'}}; $t++){
			if($json->{'routing'}{'entry'}{'mainContent'}[$t]{'type'} eq "accordion"){
				my $res = $rows->scrape($json->{'routing'}{'entry'}{'mainContent'}[$t]{'value'}{'text'});
				for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
					if($res->{'warmspaces'}[$i]{'td'}){
						$address = $res->{'warmspaces'}[$i]{'td'}[1];
						if($address =~ s/^([^\,]+)\, //){
							$title = $1;
							if($title eq "Junction 7 Creative"){ $title = "Junction 7 Creatives"; }
							if(!$places->{$title}){
								$places->{$title} = {};
							}
							$places->{$title}{'address'} = $address;
							$hours = parseText($res->{'warmspaces'}[$i]{'td'}[2]);
							$hours =~ s/^Open //gi;
							$places->{$title}{'hours'} .= ($places->{$title}{'hours'} ? "<br />":"").$json->{'routing'}{'entry'}{'mainContent'}[$t]{'value'}{'title'}.": ".$hours;
						}
					}
				}
			}
		}
		
		foreach $title (sort(keys(%{$places}))){
			$d = $places->{$title};
			$d->{'title'} = $title;
			$d->{'hours'} = parseOpeningHours({'_text'=>$d->{'hours'}});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
			push(@entries,makeJSON($d,1));
		}
#		print Dumper $places;
	}
	#print Dumper @entries;

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

