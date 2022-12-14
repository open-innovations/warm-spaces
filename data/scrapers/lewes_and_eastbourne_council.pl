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
	

	while($str =~ s/<div class="clear tabs-body-inner"><div class="contenteditor">(.*?)<\/div>/$1/s){
		$content = $1;
		
		while($content =~ s/<h3>(.*?)<\/h3>(.*?)(<h3>|$)/$3/s){
			$title = trimHTML($1);
			@p = split(/<\/p>[\n\t\s]*<p>/,$2);
			$d = {'title'=>$title};
			for($i = 0; $i < @p; $i++){
				if($p[$i] =~ /^Open/){ $d->{'hours'} = parseOpeningHours({'_text'=>trimHTML($p[$i])}); }
				elsif($p[$i] =~ /^(Telephone|Email)/){ $d->{'contact'} = ($d->{'contact'} ? $d->{'contact'}."; " : "").trimHTML($p[$i]); }
				elsif($p[$i] =~ /^\s*<p>(.*)/){ $d->{'address'} = trimHTML($p[$i]); }
				else{ $d->{'description'} = ($d->{'description'} ? $d->{'description'}."; " : "").trimHTML($p[$i]); }
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
	$str =~ s/<br ?\/?>/\n/g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^\s|\s$)//g;
	return $str;
}
