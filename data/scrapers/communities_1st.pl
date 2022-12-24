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
		process 'li[class="col xs-12 md-6 lg-4"] article', "warmspaces[]" => scraper {
			process 'h4 > a', 'title' => 'TEXT';
			process 'h4 > a', 'url' => '@HREF';
			process 'ul[class="card-meta fa-ul"] li', 'li[]' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];
		@li = @{$res->{'warmspaces'}[$i]{'li'}};
		$d->{'title'} = trimHTML($d->{'title'});

		for($l = 0; $l < @li; $l++){
			if($li[$l] =~ /<span class="bold">Location Address: ?<\/span>(.*)/i){
				$d->{'address'} = trimHTML($1);
			}elsif($li[$l] =~ /<span class="bold">More details: ?<\/span>(.*)/i){
				$d->{'description'} = trimHTML($1);
				if($d->{'description'} =~ /open (.*)/i){
					$d->{'hours'} = parseOpeningHours({'_text'=>$1});
					if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
					if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
				}
			}else{
				$d->{'description'} .= trimHTML($li[$l])."\n";
			}
		}
		if($d->{'url'} =~ /^\//){ $d->{'url'} = "https://www.communities1st.org.uk".$d->{'url'}; }

		delete $d->{'li'};

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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\, //g;
	return $str;
}
