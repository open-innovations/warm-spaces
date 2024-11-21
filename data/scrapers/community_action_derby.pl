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
	$str =~ s/\&nbsp;/ /g;

	my $rowscraper = scraper {
		process '.content--padded', 'row[]' => 'HTML';
	};

	my $res = $rowscraper->scrape( $str );
	@rows = @{$res->{'row'}};
	for($r = 0; $r < @rows; $r+=2){
		if($rows[$r] =~ /<h4>/){
			$d = {'title'=>trimHTML($rows[$r])};
			if($rows[$r+1] =~ /<strong>[^\>]*Address[^\>]*<\/strong>([^\<]*)</){
				$d->{'address'} = trimHTML($1);
			}
			if($rows[$r+1] =~ /<strong>[^\>]*Days\/times[^\>]*<\/strong>([^\<]*)</){
				$d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($1)});
				if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}{'opening'}; }
				if(!$d->{'hours'}{'_text'}){ delete $d->{'hours'}; }
			}
			push(@entries,makeJSON($d,1));
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
	$str =~ s/(<br ?\/?>|<p>)/, /g;
	$str =~ s/<[^\>]*>/ /g;
	$str =~ s/\s{2,}/ /g;
	$str =~ s/(^\s|\s$)//g;
	$str =~ s/^\, //g;
	return $str;
}
