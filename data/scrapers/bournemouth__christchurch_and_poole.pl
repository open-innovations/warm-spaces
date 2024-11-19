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

	# Start a session
	$rfile = "raw/bournemouth__christchurch_and_poole_session.json";
	$url = "https://maps.bcpcouncil.gov.uk/map/Aurora.svc/RequestSession?userName=guest&password=&script=\\Aurora\\Warm+Spaces.AuroraScript%24&callback=_jqjsp";	
	$str = `curl -s --insecure --compressed "$url"`;

	if($str =~ /"SessionId":"([^\"]+)"/){
		$session = $1;

		# We've got the session ID so now we call OpenScriptMap
		$url = "https://maps.bcpcouncil.gov.uk/map/Aurora.svc/OpenScriptMap\?sessionId=$session\&callback=_jqjsp";
		`curl -s --insecure --compressed -o "raw/bournemouth__christchurch_and_poole_openscriptmap.json" "$url"`;

		# Now we can get records
		$rfile = "raw/bournemouth__christchurch_and_poole_points.json";
		`curl -s -o $rfile 'https://maps.bcpcouncil.gov.uk/map/Aurora.svc/GetRecordsByPoint?sessionId=$session&x=405717.9530666637&y=92776.7988&radius=5000&scaleDenominator=65536' --compressed -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-GB,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br, zstd' -H 'DNT: 1' -H 'Sec-GPC: 1' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' -H 'Sec-Fetch-Dest: document' -H 'Sec-Fetch-Mode: navigate' -H 'Sec-Fetch-Site: cross-site' -H 'Priority: u=0, i' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' -H 'TE: trailers'`;

		# Open the results
		open(FILE,"<:utf8",$rfile);
		@lines = <FILE>;
		close(FILE);
		$str = join("",@lines);
		$str =~ s/\\(\"|\/|\\)/$1/g;
		$str =~ s/\\u000a/\-/g;
		
		my $warmspaces = scraper {
			process 'li', "warmspaces[]" => 'TEXT';
		};
		$res = $warmspaces->scrape( $str );

		push(@results,@{$res->{'warmspaces'}});
		for($i = 0; $i < @results; $i++){
			$d = {};
			if($results[$i] =~ /Venue name \- (.*?)\-\-/){
				$d->{'title'} = $1;
			}
			if($results[$i] =~ /\-Address \- (.*?)\-\-/){
				$d->{'address'} = $1;
			}
			if($results[$i] =~ /\-Opening times \- (.*?)\-\-/){
				$d->{'hours'} = parseOpeningHours({'_text'=>$1});
				if(!$d->{'hours'}{'opening'}){
					$d->{'description'} = $d->{'hours'}{'_text'};
					delete $d->{'hours'};
				}
			}
			if($results[$i] =~ /\-Activities \- (.*?)\-\-/){
				$d->{'description'} = ($d->{'description'} ? ". ":"").$1;
			}
			if($results[$i] =~ /\-Phone number \- (.*?)\-\-/){
				$d->{'contact'} = ($d->{'contact'} ? "; ":"")."Tel: ".$1;
			}
			if($results[$i] =~ /\-Email \- (.*?)\-\-/){
				$d->{'contact'} = ($d->{'contact'} ? "; ":"")."Email: ".$1;
			}
			push(@entries,makeJSON($d,1));
		}
	
	}else{
		warning("No session ID\n");
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
	$str =~ s/([^\.])(<\/li>|<\/p>)/$1; /g;
	$str =~ s/<[^\>]+>//g;
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	$str =~ s/\;\s\.?\s?\;/\;/g;
	$str =~ s/ ?\;$//g;
	$str =~ s/^\. //g;
	$str =~ s/\s\;\s/\; /g;
	$str =~ s/\;\s+$//g;
	return $str;
}