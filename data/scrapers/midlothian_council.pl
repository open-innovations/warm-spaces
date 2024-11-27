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

	# Replace nbsp
	$str =~ s/\&nbsp;/ /g;
	$str =~ s/\&#39;/'/g;
	# Remove empty paragraphs first - the table has loads of them
	$str =~ s/<p> <\/p>//g;
	$str =~ s/.*<h3>Bonnyrigg and Lasswade<\/h3>//gs;
	$str =~ s/<div class="feedback-container">.*//gs;
	$str =~ s/.*<h3>[^\<]*?<\/h3>//g;
	# Fix bad formatting by the council
	$str =~ s/<p>(<a [^\>]+>)<strong>([^\<]+)<\/strong>(<\/a>)(.*?)<\/p>/<h4>$1$2$3$4<\/h4>/g;
	$str =~ s/<p><strong>(.*?)<\/strong><\/p>/<h4>$1<\/h4>/g;
	$str .= "<h4>";

	while($str =~ s/<h4>(.*?)<\/h4>(.*?)<h4>/<h4>/s){
		$d = {};
		$address = $1;
		$txt = $2;
		if($address =~ /href="([^\"]+)"/){
			$d->{'url'} = $1;
		}
		$d->{'address'} = trimHTML($address);
		if($d->{'address'} =~ /^([^\,]+),/){
			$d->{'title'} = $1;
		}
		$hours = "";
		if($txt =~ /<ul>(.*?)<\/ul>/s){
			$list = $1;
			while($list =~ s/<li>(.*?)<\/li>//s){
				$li_orig = $1;
				$li = trimHTML($1);
				if($li =~ /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|holidays)/i){
					$hours .= ($hours ? "; ":"").$li;
					$txt =~ s/<li>$li_orig<\/li>//s;
				}
			}
			$txt =~ s/<\/?ul>//gs;
			
		}
		$txt = trimHTML($txt);
		
		if($txt){ $d->{'description'} = $txt; }
		if($hours){
			$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
			if(!defined($d->{'hours'}{'opening'})){ delete $d->{'hours'}; }
		}
		if(!$d->{'url'}){ $d->{'url'} = "https://www.midlothian.gov.uk/info/200301/cost_of_living/645/support_coping_with_rising_living_costs/5"; }

		# Store the entry as JSON
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
	$str =~ s/<\/li>/. /g;	# Replace closing LI tags
	$str =~ s/^<[^\>]+>//g;	# Remove initial HTML tags
	$str =~ s/<\/p>/ /g;	# Replace end of paragraphs with spaces
	$str =~ s/<br ?\/?>/, /g;	# Replace <br> with commas
	$str =~ s/<[^\>]+>//g;	# Remove any remaining tags
	$str =~ s/[\t]+/ /gs;
	$str =~ s/^[\n\r\s]+//gs;
	$str =~ s/[\n\r\s\t]+$//gs;
	$str =~ s/[\n\r]+/ /gs;
	$str =~ s/ {2,}/ /g;	# De-duplicate spaces
	return $str;
}
