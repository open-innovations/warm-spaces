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

	# Build a scraper to find the pages of results
	my $pagescrape = scraper {
		process '.paging__link', "url" => '@HREF';
		process '.paging__link', "page" => '@DATA-PAGE';
	};
	
	# Build a web scraper to parse a page of results
	my $warmspaces = scraper {
		process '.item--article', "warmspaces[]" => scraper {
			process '.item__link', 'url' => '@HREF';
			process '.item__link', 'title' => 'TEXT';
		}
	};
	# Build a web scraper to parse a page of results
	my $entry = scraper {
		process '.a-heading__title', 'title' => 'TEXT';
		process '.a-intro__content', 'description' => 'TEXT';
		process '.a-body.a-body--default', 'body' => 'HTML';
	};


	my @pp = ({'page'=>1,'content'=>$str},$pagescrape->scrape($str));
	print Dumper @pp;
	my ($res,@entries,@results);
	@entries = ();

	for(my $p = 0; $p < @pp; $p++){
		if($pp[$p]{'url'}){
			$rfile = "raw/boston-council-page-$pp[$p]{'page'}.html";
			warning("\tGetting details for $p = page $pp[$p]{'page'} (<cyan>$rfile<none>)\n");
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving <green>$purl<none> to <cyan>$rfile<none>\n");
				# Download the section
				`curl -s --insecure --compressed -o $rfile "$pp[$p]{'url'}"`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$pp[$p]{'content'} = join("",@lines);
		}

		$res = $warmspaces->scrape( $pp[$p]{'content'} );
		push(@results,@{$res->{'warmspaces'}});
	}

	# Parse each result
	for($i = 0; $i < @results; $i++){
		$rfile = "raw/boston-council-result-$i.html";
		# Keep cached copy of individual URL
		$age = getFileAge($rfile);
		if($age >= 86400 || -s $rfile == 0){
			warning("\tSaving <green>$purl<none> to <cyan>$rfile<none>\n");
			# Download the section
			`curl -s --insecure --compressed -o $rfile "$results[$i]{'url'}"`;
		}
		open(FILE,"<",$rfile);
		@lines = <FILE>;
		close(FILE);
		$html = join("",@lines);

		$res = $entry->scrape( $html );
		#$d->{'title'} = $results[$i]->{'title'};
		$res->{'url'} = $results[$i]->{'url'}; 
		
		if($res->{'description'}){
			$res->{'description'} = trimText($res->{'description'});
		}
		$res->{'body'} =~ s/\&nbsp\;/ /g;
		$res->{'body'} =~ s/\&apos\;/\'/g;

		if($res->{'body'} =~ s/<h2>Organisation:<\/h2><p>(.*?)<\/p>(.*?)<[^\>]+>Contact:?<\/[^\>]+>(.*?)<[^\>]+>Details:?<\/[^\>]+>(.*)//s){
			$p1 = $1;
			$p2 = $2;
			$p3 = $3;
			$p4 = $4;
			$contact = $p3;
			$res->{'address'} = trimHTML($p1);
			$res->{'hours'} = parseOpeningHours({'_text'=>trimHTML($p2.". ".$p4)});
			if(!$d->{'hours'}{'opening'}){ delete $d->{'hours'}; }
			if(!$res->{'hours'}{'opening'}){
				$res->{'description'} = $res->{'hours'}{'_text'};
				delete $res->{'hours'};
			}
			if($contact =~ s/<p><a href="([^\"]+\@[^\"]+)"[^\>]*>(.*)<\/a><\/p>//){
				$email = $1;
				$to = $2;
				$email =~ s/^https?\:\/\///g;
				if($to =~ /email/i){
					$to =~ s/^Email //i;
					$res->{'contact'} .= ($res->{'contact'} ? "; ":"")."Email: $email";
				}
				$res->{'contact'} = trimHTML($contact)."; ".$res->{'contact'};
				$res->{'contact'} =~ s/ ([0-9]{3,}\s?[0-9]{7,})/ Tel: $1/;
			}
		}
		delete $res->{'body'};
		push(@entries,makeJSON($res,1));
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