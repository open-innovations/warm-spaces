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
		process 'div[class="panel-group accordion"] div[class="panel panel-default"]', "warmspaces[]" => scraper {
			process 'div[class="panel-title"] > a', 'title' => 'TEXT';
			process 'div[class="panel-body"]', 'body' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];

		$d->{'title'} = trimHTML($d->{'title'});
		if($d->{'title'} =~ /^([^\,]+)\, ?(.*)$/){
			$d->{'address'} = $2;
			$d->{'title'} = $1;
		}
		$hours = "";
		while($d->{'body'} =~ s/<p><strong>(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\:? ?<\/strong><\/p><ul>(.*?)<\/ul>//i){
			$hours .= ($hours ? "; " : "")."$1 ".trimHTML($2);
		}
		$temphours = $hours;
		$temphours =~ s/(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday) [^\,]*?\,/$1/g;
		$d->{'hours'} = parseOpeningHours({'_text'=>$temphours});
		$d->{'hours'}{'_text'} = $hours;
		if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
		if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
		if($d->{'body'} =~ s/<p><strong>Website: ?<\/strong>.*?<a href="([^\"]*)"//){
			$d->{'url'} = trimHTML($1);
		}
		$d->{'description'} = trimHTML($d->{'body'});
		if(!$d->{'description'}){ delete $d->{'description'}; }
		delete $d->{'body'};

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
