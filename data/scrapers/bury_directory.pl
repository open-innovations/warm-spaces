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
	
	$str =~ s/\&nbsp;/ /g;
	
	$str =~ s/.*window.REDUX_DATA = //gs;
	$str =~ s/<\/script>.*//gs;
	$str =~ s/undefined/\"\"/g;
	
	if(!$str){ $str = "{}"; }
	eval {
		$json = JSON::XS->new->decode($str);
	};
	if($@){ error("\tInvalid JSON in $file.\n"); $json = {}; }

	my @data = @{$json->{'routing'}{'mappedEntry'}{'content'}{'data'}};
	
	for($d = 0; $d < @data; $d++){
		if(ref $data[$d] eq "HASH"){
			if(defined($data[$d]{'value'}) && ref $data[$d]{'value'} eq "HASH" && defined($data[$d]{'value'}{'link'})){
				@content = @{$data[$d]{'value'}{'link'}{'content'}};
				for($c = 0; $c < @content; $c++){
					if($content[$c]{'type'} eq "_component"){
						push(@items, @{$content[$c]{'value'}{'items'}});
					}
				}
			}
		}
	}
	for($i = 0; $i < @items; $i++){
		$d = {};
		$d->{'title'} = $items[$i]{'title'};
		$items[$i]{'content'} =~ s/<p[^\>]*>//g;
		$items[$i]{'content'} =~ s/\n//g;
		@ps = split(/<\/p>/,$items[$i]{'content'});
		for($p = 0; $p < @ps; $p++){
			if($ps[$p] =~ /<strong[^\>]*>Address:?<\/strong>:? (.*)/){
				$d->{'address'} = $1;
			}
			if($ps[$p] =~ /<strong[^\>]*>Offer:?<\/strong>:? (.*)/){
				$d->{'description'} = $1;
			}
			if($ps[$p] =~ /<strong[^\>]*>Website:?<\/strong>:? <a href="([^\"]*)"/){
				$d->{'url'} = $1;
			}
			if($ps[$p] =~ /<strong[^\>]*>Email:?<\/strong>\:? .*mailto:([^\"]*)"/){
				$email = $1;
				$email =~ s/\&quot.*//g;
				$d->{'contact'} .= ($items[$i]{'contact'} ? " ":"")."Email: ".$email;
			}
			if($ps[$p] =~ /<strong[^\>]*>Opening days and times:?<\/strong>:? (.*)/){
				$d->{'hours'} = {};
				$d->{'hours'}{"_text"} = $1;
				$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
				$d->{'hours'} = parseOpeningHours($items[$i]{'hours'});
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
	$str =~ s/(<br ?\/?>|<\/p>)/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
