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

# Loop over the directories
for($i = 0, $j = 1; $i < $n; $i++, $j++){

	# Get the data for this one
	$d = $data->{'directories'}[$i];

	# Add an ID if we haven't provided one
	if(!$d->{'id'}){ $d->{'id'} = getID($d->{'title'}); }

	$sources->{$d->{'id'}} = $d;

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
			$nf = @{$geojson->{'features'}};
			if($nf == 0){
				warning("\tNo features for $d->{'title'}\n");
			}else{

				# For each feature 
				for($f = 0; $f < $nf; $f++){
					$json = parseGeoJSONFeature($geojson->{'features'}[$f],$d->{'data'}{'keys'});
					$json->{'_source'} = $d->{'id'};
					push(@warmplaces,$json);
				}
				msg("\tAdded $nf features.\n");
				$total += $nf;
			}
		}elsif($d->{'data'}{'type'} eq "storepoint"){

			# Get the data (if we don't have a cached version)
			$file = getDataFromURL($d);

			msg("\tProcessing Storepoint data\n");
			$json = getJSON($file);

			$nf = @{$json->{'results'}{'locations'}};
			if($nf == 0){
				warning("\tNo features for $d->{'title'}\n");
			}else{

				# For each feature 
				for($f = 0; $f < $nf; $f++){
					$rtnjson = parseStorepointFeature($json->{'results'}{'locations'}[$f],$d->{'data'}{'keys'});
					$rtnjson->{'_source'} = $d->{'id'};
					push(@warmplaces,$rtnjson);
				}

				msg("\tAdded $nf features.\n");
				$total += $nf;
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

					$nf = @{$json};
					for($f = 0; $f < $nf; $f++){
						$json->[$f]{'_source'} = $d->{'id'};
						push(@warmplaces,$json->[$f]);
					}
					msg("\tAdded $nf features.\n");
					$total += $nf;
				}else{
					warning("\tNo JSON returned from scraper\n");
				}
			}

		}
	}
}
open($fh,">:utf8",$dir."places.json");
print $fh makeJSON(\@warmplaces);
close($fh);

open($fh,">:utf8",$dir."sources.json");
print $fh makeJSON($sources,1);
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

	print "\tFile: $file\n";
	if($age >= 86400){
		`wget -q -e robots=off  --no-check-certificate -O $file "$url"`;
		print "\tDownloaded\n";
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

