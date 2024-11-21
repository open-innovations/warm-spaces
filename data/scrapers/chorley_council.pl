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
	$str =~ s/\&ndash;/\-/g;
	$str =~ s/\&eacute;/é/g;
	$str =~ s/\&#39;/'/g;

	# Build a web scraper
	my $warmspaces = scraper {
		process 'tr', "warmspaces[]" => scraper {
			process 'td', 'td[]' => 'HTML';
			process 'th', 'th[]' => 'HTML';
		}
	};
	@tables;
	while($str =~ s/<h2>(.*?)<\/h2>[\n\r]*(<table>.*?<\/table>)//s){
		push(@tables,{'title'=>trimHTML($1),'table'=>$2});
	}

	my %places;

	for($t = 0; $t < @tables; $t++){

		$res = $warmspaces->scrape( $tables[$t]->{'table'} );
		
		for($i = 1; $i < @{$res->{'warmspaces'}}; $i++){

			$area = $res->{'warmspaces'}[$i];

			$place = $area->{'td'}[0];
			if($place =~ /<p>(.*?)<\/p>/){
				$place = $1;
			}
			# Fix for typo
			if($place eq "Chorley Buddies)"){ $place = "Chorley Buddies"; }
			if(!defined($places{$place})){
				$places{$place} = {'title'=>$place,'hours'=>{'_text'=>''}};
			}
			if(!defined($places{$place}{'address'})){
				$places{$place}{'address'} = trimHTML($area->{'td'}[2]);
			}
			if($tables[$t]->{'title'} =~ /(.*)\'s/){
				$places{$place}{'hours'}{'_text'} .= ($places{$place}{'hours'}{'_text'} ? "; ":"").$1." ".trimHTML($area->{'td'}[1]);
			}elsif($tables[$t]->{'title'} eq "Across the borough all week"){
				$places{$place}{'hours'}{'_text'} .= ($places{$place}{'hours'}{'_text'} ? "; ":"").trimHTML($area->{'td'}[1]);
			}
		}
	}
	foreach $place (sort(keys(%places))){
		$places{$place}{'hours'} = parseOpeningHours($places{$place}{'hours'});
		if(!$places{$place}{'hours'}{'opening'}){ delete $places{$place}{'hours'}; }
		push(@entries,makeJSON($places{$place},1));
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