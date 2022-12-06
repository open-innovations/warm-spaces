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

	%places;
	while($str =~ s/<h3>(.*?)<\/h3>(<ul>.*?)(<h3>|<hr>)/$3/s){

		$day = $1;
		$content = "<div>".$2."</div>";


		# Build a web scraper
		$warmspaces = scraper {
			process 'div > ul > li', "li[]" => scraper {
				process 'li', 'li[]', 'HTML';
			}
		};

		my $res = $warmspaces->scrape( $content );
		for($l = 0; $l < @{$res->{'li'}}; $l++){
			if(@{$res->{'li'}[$l]{'li'}} == 3){
				$title = "";
				$hours = "";
				if($res->{'li'}[$l]{'li'}[0] =~ /<strong>([^\<]*?) ?- ([^\<]*?)<\/strong>/){
					$hours = $1;
					$title = $2;
					$title =~ s/:$//g;
				}
				
				@li = ();
				while($res->{'li'}[$l]{'li'}[0] =~ s/<li>(.*?)<\/li>//s){
					push(@li,$1);
				}

				$key = $title."=".$li[0];


				if(!$places{$key}){ $places{$key} = {'title'=>$key,'hours'=>{'_text'=>''},'address'=>$li[0]}; }
				$places{$key}{'hours'}{'_text'} .= ($places{$key}{'hours'}{'_text'} ? "; ":"")."$day: $1";
				$places{$key}{'description'} .= ($places{$key}{'description'} ? ", ":"")."$day: ".$li[1];
				
			}
		}
	}


	foreach $p (sort(keys(%places))){
		$places{$p}{'hours'} = parseOpeningHours($places{$p}{'hours'});
		$places{$p}{'description'} =~ s/<ul><\/ul>//g;
		push(@entries,makeJSON($places{$p},1));
	}

	open(FILE,">:utf8","$file.json");
	print FILE "[\n".join(",\n",@entries)."\n]";
	close(FILE);

	print $file.".json";

}else{

	print "";

}

