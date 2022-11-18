#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
use YAML::XS 'LoadFile';
use Encode;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';

$dir = "./";
$rawdir = "raw/";
#makeDir($dir);
makeDir($rawdir);


#print Dumper parseOpeningHours({'_text'=>'&lsquo;Soup Socials&rsquo; will operate from noon to 2pm on Mondays.'});
#print Dumper parseOpeningHours({'_text'=>'Open 10am to 6pm, 7 days a week'});


@warmplaces;
$sources;

# Load the main config file
my $data = LoadFile('data.yml');

# How many directories do we have
my $n = @{$data->{'directories'}};

my $total = 0;
my $table = "";

# Loop over the directories
for($i = 0, $j = 1; $i < $n; $i++, $j++){

	# Get the data for this one
	$d = $data->{'directories'}[$i];

	# Add an ID if we haven't provided one
	if(!$d->{'id'}){ $d->{'id'} = getID($d->{'title'}); }

	# Print the title of this one
	msg("$j: <cyan>$d->{'title'}<none>\n");

	# If there is data
	if($d->{'data'}){

		# If the data type is GeoJSON
		if($d->{'data'}{'type'} eq "geojson"){

			# Get the data (if we don't have a cached version)
			$file = getDataFromURL($d);

			msg("\tProcessing GeoJSON\n");
			$geojson = getJSON($file);

			# How many features in the GeoJSON
			$d->{'count'} = @{$geojson->{'features'}};
			if($d->{'count'} == 0){
				warning("\tNo features for $d->{'title'}\n");
			}else{

				# For each feature 
				for($f = 0; $f < $d->{'count'}; $f++){
					$json = parseGeoJSONFeature($geojson->{'features'}[$f],$d->{'data'}{'keys'});
					$json->{'_source'} = $d->{'id'};
					push(@warmplaces,$json);
				}
				msg("\tAdded $d->{'count'} features.\n");
				$total += $d->{'count'};
			}
		}elsif($d->{'data'}{'type'} eq "storepoint"){

			# Get the data (if we don't have a cached version)
			$file = getDataFromURL($d);

			msg("\tProcessing Storepoint data\n");
			$json = getJSON($file);

			$d->{'count'} = @{$json->{'results'}{'locations'}};
			if($d->{'count'} == 0){
				warning("\tNo features for $d->{'title'}\n");
			}else{

				# For each feature 
				for($f = 0; $f < $d->{'count'}; $f++){
					$rtnjson = parseStorepointFeature($json->{'results'}{'locations'}[$f],$d->{'data'}{'keys'});
					$rtnjson->{'_source'} = $d->{'id'};
					push(@warmplaces,$rtnjson);
				}

				msg("\tAdded $d->{'count'} features.\n");
				$total += $d->{'count'};
			}

		}elsif($d->{'data'}{'type'} eq "html"){

			# Find the scraping file
			$scraper = "scrapers/$d->{'id'}.pl";

			if(-e $scraper){

				# Get the data (if we don't have a cached version)
				$file = getDataFromURL($d);

				msg("\tParsing web page\n");

				$str = `perl $scraper $file`;

				if(-e $str){
					open(FILE,$str);
					@lines = <FILE>;
					close(FILE);
					$str = join("",@lines);

					eval {
						$json = JSON::XS->new->decode($str);
					};
					if($@){ warning("\tInvalid output from scraper.\n".$str); }

					$d->{'count'} = @{$json};
					for($f = 0; $f < $d->{'count'}; $f++){
						$json->[$f]{'_source'} = $d->{'id'};
						push(@warmplaces,$json->[$f]);
					}
					msg("\tAdded $d->{'count'} features.\n");
					$total += $d->{'count'};
				}else{
					warning("\tNo JSON returned from scraper\n");
				}
			}

		}elsif($d->{'data'}{'type'} eq "squarespace"){

			@features = getSquareSpace($d);
			$d->{'count'} = @features;
			for($f = 0; $f < $d->{'count'}; $f++){
				push(@warmplaces,$features[$f])
			}
			msg("\tAdded $nf features.\n");
			$total += $d->{'count'};
			
		}
	}
	$table .= "<tr>";
	$table .= "<td><a href=\"$d->{'url'}\">$d->{'title'}</a></td>";
	$table .= "<td>".($d->{'count'} ? $d->{'count'} : "?")."</td>";
	$table .= "<td>".($d->{'map'} && $d->{'map'}{'url'} ? "<a href=\"$d->{'map'}{'url'}\">Map</a>":"")."</td>";
	$table .= "<td>".($d->{'register'} && $d->{'register'}{'url'} ? "<a href=\"$d->{'register'}{'url'}\">Add a warm place</a>":"")."</td>";
	$table .= "</tr>\n";

	$sources->{$d->{'id'}} = $d;
	if($sources->{$d->{'id'}}{'count'}){
		$sources->{$d->{'id'}}{'count'} += 0;
	}
}
open($fh,">:utf8",$dir."places.json");
print $fh makeJSON(\@warmplaces);
close($fh);

open($fh,">:utf8",$dir."sources.json");
print $fh tidyJSON($sources,2);
close($fh);

open($fh,">:utf8",$dir."summary.html");
print $fh "<table>\n";
print $fh "<thead><tr><td>Directory</td><td>Entries</td><td>Map</td><td>Register</td></thead></tr>\n";
print $fh "<tbody>\n";
print $fh $table;
print $fh "</tbody>\n";
print $fh "</table>\n";
close($fh);




msg("Added $total features in total.\n");

################
# SUBROUTINES
sub getID {
	my $str = $_[0];
	$str = lc($str);
	$str =~ s/[^a-z0-9\-\_]/\_/g;
	return $str;
}
sub makeDir {
	my $str = $_[0];
	my @bits = split(/\//,$str);
	my $tdir = "";
	my $i;
	for($i = 0; $i < @bits; $i++){
		$tdir .= $bits[$i]."/";
		if(!-d $tdir){
			`mkdir $tdir`;
		}
	}
}
sub getDataFromURL {
	my $d = shift;
	my $url = $d->{'data'}{'url'};

	my $file = $rawdir.$d->{'id'}.".".$d->{'data'}{'type'};
	my $age = 100000;
	if(-e $file){
		my $epoch_timestamp = (stat($file))[9];
		my $now = time;
		$age = ($now-$epoch_timestamp);
	}

	msg("\tFile: $file\n");
	if($age >= 86400){
		`wget -q -e robots=off  --no-check-certificate -O $file "$url"`;
		msg("\tDownloaded\n");
	}
	return $file;
}

sub getURL {
	my $url = $_[0];
	my $file = $_[1];
	my ($age,$now,$epoch_timestamp);

	$age = 100000;
	if(-e $file){
		$epoch_timestamp = (stat($file))[9];
		$now = time;
		$age = ($now-$epoch_timestamp);
	}

	msg("\tDownload $url\n");
	if($age >= 86400 || -s $file == 0){
		`wget -q -e robots=off  --no-check-certificate -O $file "$url"`;
		msg("\tDownloaded\n");
	}
	return $file;
}

sub parseStorepointFeature {
	my $f = shift;
	my $keys = shift;
	my $json = {'hours'=>{}};
	my @fields = ("title","address","lat","lon","description","accessibility","type");
	my($i,@days);

	for($i = 0; $i < @fields; $i++){
		if($f->{$fields[$i]}){ $json->{$fields[$i]} = $f->{$fields[$i]}; }
		if($keys->{$fields[$i]} && $f->{$keys->{$fields[$i]}}){ $json->{$fields[$i]} = $f->{$keys->{$fields[$i]}}; }
	}

	# Explicit days
	@days = ("monday","tuesday","wednesday","thursday","friday","saturday","sunday");
	$json->{'hours'}{'_parsed'} = "";
	for($i = 0; $i < @days; $i++){
		if($f->{$days[$i]}){ $json->{'hours'}{$days[$i]} = $f->{$days[$i]}; }
		if($keys->{$days[$i]} && $f->{$keys->{$days[$i]}}){ $json->{'hours'}{$days[$i]} = $f->{$keys->{$days[$i]}}; }

		$json->{'hours'} = parseOpeningHours($json->{'hours'});
	}

	return $json;
}

sub parseGeoJSONFeature {
	my $f = shift;
	my $keys = shift;
	my $json = {'hours'=>{}};
	my @fields = ("title","address","lat","lon","description","accessibility","type");
	my ($i);
	for($i = 0; $i < @fields; $i++){
		if($f->{'properties'}{$fields[$i]}){ $json->{$fields[$i]} = $f->{'properties'}{$fields[$i]}; }
		if($keys->{$fields[$i]} && $f->{'properties'}{$keys->{$fields[$i]}}){ $json->{$fields[$i]} = $f->{'properties'}{$keys->{$fields[$i]}}; }
	}

	# Explicit days
	my @days = ("monday","tuesday","wednesday","thursday","friday","saturday","sunday");
	for($i = 0; $i < @days; $i++){
		if($f->{'properties'}{$days[$i]}){ $json->{'hours'}{$days[$i]} = $f->{'properties'}{$days[$i]}; }
		if($keys->{$days[$i]} && $f->{'properties'}{$keys->{$days[$i]}}){ $json->{'hours'}{$days[$i]} = $f->{'properties'}{$keys->{$days[$i]}}; }
	}

	# Deal with hours
	if($f->{'properties'}{'hours'}){ $json->{'hours'}{'_text'} = $f->{'properties'}{'hours'}; }
	if($keys->{'hours'} && $f->{'properties'}{$keys->{'hours'}}){ $json->{'hours'}{'_text'} = $f->{'properties'}{$keys->{'hours'}}; }

	$json->{'hours'} = parseOpeningHours($json->{'hours'});
	# If we haven't explicitly been sent lat/lon in the properties we get it from the coordinates
	if(!$json->{'lat'}){ $json->{'lat'} = $f->{'geometry'}{'coordinates'}[1]; }
	if(!$json->{'lon'}){ $json->{'lon'} = $f->{'geometry'}{'coordinates'}[0]; }
	return $json;
}

sub getSquareSpace {
	my $d = shift;
	my $keys = shift;
	my ($url,$page,$p,@items,$purl,$i,$n,$json,$f);
	my @fields = ("title","address","lat","lon","description","accessibility","type");

	$url = $d->{'data'}{'url'}."?format=json-pretty";

	$p = 1;
	$page = $rawdir.$d->{'id'}."-$p.json";
	getURL($url,$page);
	$json = getJSON($page);
	
	@items = @{$json->{'items'}};
	
	while($json->{'pagination'}{'nextPage'}){
		$purl = $url."&offset=$json->{'pagination'}{'nextPageOffset'}";
		$p++;
		$page = $rawdir.$d->{'id'}."-$p.json";
		getURL($purl,$page);
		$json = getJSON($page);
		@items = (@items,@{$json->{'items'}});
		$n = @items;
	}
	print "$n items\n";
	
	@features;

	for($i = 0; $i < @items; $i++){
			
		$json = {};
		for($f = 0; $f < @fields; $f++){
			if($items[$i]{$fields[$f]}){ $json->{$fields[$f]} = $items[$i]{$fields[$f]}; }
			if($keys->{$fields[$f]} && $items[$i]{$keys->{$fields[$f]}}){ $json->{$fields[$f]} = $items[$i]{$keys->{$fields[$f]}}; }
		}
		$json->{'lat'} = $items[$i]{'location'}{'mapLat'}+0;
		$json->{'lon'} = $items[$i]{'location'}{'mapLng'}+0;
		$json->{'address'} = $items[$i]{'location'}{'addressLine1'}.", ".$items[$i]{'location'}{'addressLine2'};
		if($items[$i]{'excerpt'} =~ /<a href="([^\"]+)">Find out more<\/a>/){ $json->{'url'} = $1; }
		if($items[$i]{'excerpt'} =~ /<strong>Opening Hours:<\/strong> (.*?)<br>/){ $json->{'hours'} = {'_text'=>$1}; }
		$json->{'hours'} = parseOpeningHours($json->{'hours'});

		$json->{'_source'} = $d->{'id'};
		
		push(@features,$json);
	}
	return @features;
}
