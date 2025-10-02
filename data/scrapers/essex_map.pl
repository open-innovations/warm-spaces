#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
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


	# Build a web scraper
	my $warmspaces = scraper {
		process 'article.gd_place_tags-warm-spaces, article.gd_placecategory-warm-spaces1, article.gd_placecategory-warm-spaces', "warmspaces[]" => scraper {
			process 'h1', 'title' => 'TEXT';
			process 'a', 'url' => '@HREF';
			process '*', 'id' => '@ID';
			process '.gd-bh-open-hours .dropdown-item', 'days[]' => scraper {
				process '.gd-bh-days-d', 'day' => 'HTML';
				process '.gd-bh-slot-r', 'times' => 'HTML';
			}
		}
	};
	
	# Find the map widget properties
	$coords = {};
	if($str =~ /var wp_widget_gd_map = ([^\;]*?);/){
		$json = $1;
		if(!$json){ $json = "{}"; }
		eval {
			$json = JSON::XS->new->decode($json);
		};
		if($@){ error("\tInvalid output in $file.\n"); $json = {}; }
		$json = parseJSON(getURL($json->{'map_markers_ajax_url'}."&post_type=".$json->{'post_type'}."&_wpnonce=".$json->{'_wpnonce'}));
		foreach $item (@{$json->{'items'}}){
			$coords->{$item->{'m'}} = {'lat'=>$item->{'lt'},'lon'=>$item->{'ln'},'title'=>$item->{'t'}};
		}
	}


	# Loop over pages
	$next = "placeholder";
	$n = 0;
	while($next){
		if($n>0){
			# Get new page here
			$rfile = "raw/essex_map-page$n.html";
			# Keep cached copy of individual URL
			$age = getFileAge($rfile);
			if($age >= 86400 || -s $rfile == 0){
				warning("\tSaving page $n (<green>$next<none>) to <cyan>$rfile<none>\n");
				# For each entry we now need to get the sub page to find the location information
				`curl '$next' -o $rfile -s --insecure -L --compressed -H 'Upgrade-Insecure-Requests: 1' -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0" -H "Accept-Language: en-GB,en;q=0.5" -H "Accept-Encoding: gzip, deflate"`;
			}
			open(FILE,"<:utf8",$rfile);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);
		}


		# Get next page link
		if($str =~ /"next page-link".*?href="([^\"]+)"/){
			$n++;
			$next = $1;
			$next =~ s/\&\#038;/\&/g;
		}else{
			$next = "";
		}

		# Parse listing page
		$warm = $warmspaces->scrape( $str );

		for($j = 0; $j < @{$warm->{'warmspaces'}}; $j++){
			$d = $warm->{'warmspaces'}[$j];
			$d->{'id'} =~ s/post-//g;

		
			if(defined($coords->{$d->{'id'}})){
				$d->{'lat'} = $coords->{$d->{'id'}}{'lat'};
				$d->{'lon'} = $coords->{$d->{'id'}}{'lon'};
				if(defined($d->{'days'})){
					$hours = "";
					for($i = 0; $i < @{$d->{'days'}}; $i++){
						if($d->{'days'}[$i]{'times'} ne "Closed"){
							$hours .= ($hours ? ", ":"").$d->{'days'}[$i]{'day'}." ".$d->{'days'}[$i]{'times'};
						}
					}
					$d->{'hours'} = parseOpeningHours({'_text'=>$hours});
					delete $d->{'days'};
				}
			}
			delete $d->{'id'};
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
	$str =~ s/(^[\s\t\n\r]+|[\s\t\n\r]+$)//g;
	$str =~ s/[\n\r]{2,}/\n/g;
	$str =~ s/[\s\t]{2,}/ /g;
	return $str;
}
