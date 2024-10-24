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
		process '.tableprimary tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
			process 'th', 'th[]' => 'HTML';
		}
	};
	
	@tables;
	while($str =~ s/<h2>(.*?)<\/h2>(<table class="tableprimary".*?<\/table>)//){
		push(@tables,{'title'=>trimHTML($1),'table'=>$2});
	}

	for($t = 0; $t < @tables; $t++){

		$res = $warmspaces->scrape( $tables[$t]->{'table'} );
		
		for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){

			$area = $res->{'warmspaces'}[$i];

			$d = {};
			@ps = ();
			while($area->{'td'}[0] =~ s/<p>(.*?)<\/p>//){
				push(@ps,$1);
			}


			if($tables[$t]->{'title'} eq "Available Warm Spaces"){
				
				while($area->{'td'}[0] =~ s/<p>(.*?)<\/p>//){
					push(@ps,$1);
				}
				if(@ps > 0){
					$d->{'title'} = parseText($ps[0]);
					if(@ps > 1 && $ps[1] =~ /<a[^\>]+href="([^\"]+)"/){
						$d->{'url'} = $1;
						if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://chorley.gov.uk".$d->{'url'}; }
					}
					if(@ps > 2){
						$d->{'description'} = parseText($ps[2]);
					}
				}else{
					$d->{'title'} = parseText($area->{'td'}[0]);
				}

				$d->{'hours'} = parseOpeningHours({'_text'=>$area->{'td'}[1]});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
				if($area->{'td'}[2]){ $d->{'address'} = parseText($area->{'td'}[2]); }


			}elsif($tables[$t]->{'title'} eq "LCC Library Warm Spaces"){
				
				#$d->{'title'} = parseText($area->{'td'}[0])." Library";

			}elsif($tables[$t]->{'title'} eq "Chorley Buddies Food Clubs"){
				
				#$title = parseText($area->{'td'}[0]);
				#if($title =~ s/^([^\,]+)\, //){
				#	$d->{'title'} = $1;
				#	$d->{'address'} = $title;
				#}
				#$d->{'hours'} = parseOpeningHours({'_text'=>$area->{'td'}[1]});
				#if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
				
			}
			if($d->{'title'}){
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


sub trimHTML {
	my $str = $_[0];
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}