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
	$str =~ s/\&\#8211;/-/g;
	$str =~ s/\&\#8217;/\'/g;


	# Build a web scraper
	my $warmspaces = scraper {
		process 'div.wp-block-columns', "warmspaces[]" => scraper {
			process 'h3', 'title' => 'HTML';
			process 'p', 'p[]' => 'HTML';
		};
	};
	my $res = $warmspaces->scrape( $str );

	for($i = 0; $i < @{$res->{'warmspaces'}}; $i++){
		$d = $res->{'warmspaces'}[$i];

		$d->{'title'} = trimHTML($d->{'title'});
		

		@ps = @{$d->{'p'}};

		# Manual address fixes
		if($d->{'title'} =~ /3 Villages Community Hall/){
			$ps[0] .= ", G83 7AB";
		}elsif($d->{'title'} =~ /Port Gala Team/){
			$ps[0] .= ", PA20 0LL";
		}elsif($d->{'title'} =~ /Lochgoilhead Village Hall/){
			$ps[0] .= ", PA24 8AQ";
		}elsif($d->{'title'} =~ /An Cridhe Community Centre/){
			$ps[0] .= ", PA78 6SY";
		}elsif($d->{'title'} =~ /Inveraray Hub/){
			$ps[0] .= ", PA32 8UY";
		}elsif($d->{'title'} =~ /Mactaggart Youth and Community Outreach Services/){
			$ps[0] .= ", PA42 7BJ";
		}

		for($p = 0; $p < @ps; $p++){
			if($p==0){
				if($ps[$p] =~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/){
					$address = $ps[$p];
					$address =~ s/ ?<br> ?/, /g;
					$address =~ s/\<[^\>]*\>//g;
					$address =~ s/(^ | $)//g;
					$d->{'address'} = $address;
				}
			}else{
				if($ps[$p] =~ /(Mon|Tue|Wed|Thu|Fri|Sat|Sun|every day)/i && $ps[$p] =~ /<strong>/i){
					if(!defined($d->{'hours'})){
						$d->{'hours'} = {'_text'=>''};
					}
					# Fix for times of the form: "Open every day, 10-4"
					if($ps[$p] =~ /([0-9]{1,2})-([0-9]{1,2})(\s?\<|$)/){
						$s = $1;
						$e = $2;
						$enew = $e;
						if($e < $s){
							$enew = $e . "pm";
						}
						$ps[$p] =~ s/$s-$e/$s-$enew/;
					}
					@br = split(/<br>/,$ps[$p]);
					for($b = 0; $b < @br; $b++){
						$d->{'hours'}{'_text'} .= ($d->{'hours'}{'_text'} ? '; ':'').$br[$b];
					}
				}else{
					$ps[$p] = trimHTML($ps[$p]);
					$d->{'description'} .= ($d->{'description'} ? " ":"").$ps[$p];
				}
			}
		}
		if(defined($d->{'hours'})){
			$d->{'hours'}{'_text'} =~ s/<[^\>]+>/ /g;
			$d->{'hours'} = parseOpeningHours($d->{'hours'});
		}
		delete $d->{'p'};
		if(defined($d->{'address'})){
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
	$str =~ s/(<br ?\/?>|<p>)/\n /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}