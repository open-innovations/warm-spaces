#!/usr/bin/perl

my $basedir;
BEGIN {
	$basedir = $0;
	$basedir =~ s/[^\/]*$//g;
	if(!$basedir){ $basedir = "./"; }
	$lib = $basedir."";
}
use lib $lib;
use utf8;
use JSON::XS;
use YAML::XS 'LoadFile';
use Data::Dumper;
use OpenInnovations::Log;
use POSIX qw(strftime);
use Encode;
use Geo::Coordinates::OSGB qw(ll_to_grid grid_to_ll);
use List::Util qw( min max );
require "lib.pl";
binmode STDOUT, 'utf8';


my $log = OpenInnovations::Log->new()->open("build.log");
$log->msg("Build started: ".strftime("%FT%H:%M:%S", localtime)."\n\n");


$dir = "../docs/data/";
$rawdir = "raw/";
makeDir($rawdir);
$pcfile = $basedir."postcodes.tsv";


loadPostcodes($pcfile);
processDirectories();
savePostcodes($pcfile);




#################################

sub processDirectories {

	my ($i,$j,$k,$d,@features,@nfeatures,$file,$json,$f,$rtnjson,$scraper,$json,$feat,$n,@warmplaces,$sources);
	
	# Load the main config file
	my $data = LoadFile('data.yml');

	# How many directories do we have
	my $n = @{$data->{'directories'}};

	my $total = 0;
	my $totalgeo = 0;
	my $totaldir = 0;
	my $totalgeocoded = 0;
	my $table = "";
	my $key = $ARGV[0];
	my $stime,$etime,$diff;


	# Loop over the directories
	for($i = 0, $j = 1; $i < $n; $i++, $j++){

		# Get the data for this one
		$d = $data->{'directories'}[$i];

		# Add an ID if we haven't provided one
		if(!$d->{'id'}){ $d->{'id'} = getID($d->{'title'}); }

		# Print the title of this one
		$log->msg("$j: <cyan>$d->{'title'}<none> ($d->{'id'})\n");
		$stime = time;

		@features = ();

		# If there is data
		if(!$d->{'inactive'} && $d->{'data'} && (!$key || ($key && $d->{'id'} eq $key))){

			# If the data structure is a HASH we turn it into an array of hashes
			if(ref $d->{'data'} eq "HASH"){
				$d->{'data'} = [$d->{'data'}];
			}


			for($k = 0; $k < @{$d->{'data'}}; $k++){

				@nfeatures = ();

				# If the data type is GeoJSON
				if($d->{'data'}[$k]{'type'} eq "arcgis"){

					@nfeatures = getArcGIS($d,$k);
					
				}elsif($d->{'data'}[$k]{'type'} eq "geojson"){

					@nfeatures = getGeoJSON($d,$k);

				}elsif($d->{'data'}[$k]{'type'} eq "xls"){

					@nfeatures = getXLSX($d,$k);

				}elsif($d->{'data'}[$k]{'type'} eq "storepoint"){

					@nfeatures = getStorePoint($d,$k);

				}elsif($d->{'data'}[$k]{'type'} eq "googlemap"){
					
					@nfeatures = getGoogleMap($d,$k);
					
				}elsif($d->{'data'}[$k]{'type'} eq "csv"){
					
					@nfeatures = getCSV($d,$k);
					
				}elsif($d->{'data'}[$k]{'type'} eq "html"){

					@nfeatures = getHTML($d,$k);

				}elsif($d->{'data'}[$k]{'type'} eq "wpgeodir"){
					
					@nfeatures = getWPGeoDir($d,$k);
					
				}elsif($d->{'data'}[$k]{'type'} eq "squarespace"){

					@nfeatures = getSquareSpace($d,$k);

				}
				push(@features,@nfeatures);
			}
			$d->{'count'} = @features;
			$d->{'geocount'} = 0;
			for($f = 0; $f < @features; $f++){
				if($features[$f]{'lat'} && $features[$f]{'lon'}){
					# Truncate coordinates to remove unnecessary precision (no need for better than 1m)
					$features[$f]{'lat'} = sprintf("%0.5f",$features[$f]{'lat'})+0;
					$features[$f]{'lon'} = sprintf("%0.5f",$features[$f]{'lon'})+0;
					$d->{'geocount'}++;
				}

				# Fix issue with tabs inside properties
				foreach $feat (sort(keys(%{$features[$f]}))){
					if($features[$f]{$feat} =~ /[\t]/){
						$features[$f]{$feat} =~ s/[\t]$//g;
						$features[$f]{$feat} =~ s/[\t]/ /g;
					}
					$features[$f]{$feat} =~ s/[\s\t]{2,}/ /g;
					$features[$f]{$feat} =~ s/(^\s|\s$)//g;
					if(!$features[$f]{$feat}){ delete $features[$f]{$feat}; }
				}
				if($features[$f]{'loc_pcd'}){ $totalgeocoded++; }
				push(@warmplaces,$features[$f]);
			}

			$log->msg("\tAdded $d->{'count'} features ($d->{'geocount'} geocoded).\n");
			$total += $d->{'count'};
			$totalgeo += $d->{'geocount'};
			if($d->{'count'} > 0){ $totaldir++; }
			
			$counter = @warmplaces;
			$log->msg("\tTotal = $counter\n");

		}
		$table .= "<tr".($d->{'inactive'} ? " class=\"inactive\"" : "").">";
		$table .= "<td><a href=\"$d->{'url'}\">$d->{'title'}</a></td>";
		$table .= "<td>".($d->{'count'} ? $d->{'count'} : "?")."</td>";
		$table .= "<td".($d->{'geocount'} ? " class=\"c13-bg\"":"").">".($d->{'geocount'} ? $d->{'geocount'} : "")."</td>";
		$table .= "<td>".($d->{'map'} && $d->{'map'}{'url'} ? "<a href=\"$d->{'map'}{'url'}\">Map</a>":"")."</td>";
		$table .= "<td>".($d->{'register'} && $d->{'register'}{'url'} ? "<a href=\"$d->{'register'}{'url'}\">Add a warm place</a>":"")."</td>";
		$table .= "<td>".($d->{'notes'} ? $d->{'notes'}:"").($d->{'inactive'} ? " Inactive as of ".$d->{'inactive'} : "")."</td>";
		$table .= "</tr>\n";

		# Remove the data structure as we don't want to store that in the JSON
		delete $d->{'data'};

		$sources->{$d->{'id'}} = $d;
		if($sources->{$d->{'id'}}{'count'}){
			$sources->{$d->{'id'}}{'count'} += 0;
		}
		if($sources->{$d->{'id'}}{'geocount'}){
			$sources->{$d->{'id'}}{'geocount'} += 0;
		}

		$etime = time;
		$diff = ($etime-$stime);
		if($diff > 0){
			$log->msg("\tProcessed in <yellow>".($diff)."<none> second".($diff==1 ? "":"s")."\n");
		}
	}
	open($fh,">:utf8",$dir."places.json");
	print $fh tidyJSON(\@warmplaces,1);
	close($fh);
	
	open($fh,">:utf8",$dir."places.geojson");
	print $fh "{\n\t\"type\": \"FeatureCollection\"\,\n\t\"features\":[\n";
	$n = 0;
	for($f = 0; $f < @warmplaces; $f++){
		if(defined $warmplaces[$f]->{'lat'} && defined $warmplaces[$f]->{'lon'}){
			if($n > 0){
				print $fh "\,\n";
			}
			print $fh "\t\t{";
			print $fh "\"type\":\"Feature\",\"geometry\":{\"coordinates\":[$warmplaces[$f]->{'lon'},$warmplaces[$f]->{'lat'}],\"type\":\"Point\"},\"properties\":";
			delete $warmplaces[$f]->{'lon'};
			delete $warmplaces[$f]->{'lat'};
			print $fh tidyJSON($warmplaces[$f],0,1);
			print $fh "}";
			$n++;
		}
	}
	print $fh "\n\t]\n}\n";
	close($fh);
	
	

	open($fh,">:utf8",$dir."sources.json");
	print $fh tidyJSON($sources,2);
	close($fh);

#	$ts = strftime("%A %e %B %I:%M %p",localtime);
	$ts = "<time datetime=\"".strftime("%FT%X%z", localtime)."\">".strftime("%A %e %B %I:%M %p", localtime)."</time>";
	$ts =~ s/ 0([0-9])/ $1/g;
	$ts =~ s/ AM/ am/g;
	$ts =~ s/ PM/ pm/g;
	$ts =~ s/:00 / /g;

	open($fh,">:utf8",$dir."summary.html");
	print $fh "<p>As of $ts.</p>\n";
	print $fh "<table>\n";
	print $fh "<thead><tr><th>Directory</th><th>Entries</th><th>Geocoded</th><th>Map</th><th>Register</th><th>Notes</th></thead></tr>\n";
	print $fh "<tbody>\n";
	print $fh $table;
	print $fh "</tbody>\n";
	print $fh "</table>\n";
	close($fh);

	$log->msg("Added $total features in total ($totalgeo geocoded from $totaldir directories).\n");
	open($fh,">:utf8",$dir."ndirs.txt");
	print $fh "$totaldir";
	close($fh);
	open($fh,">:utf8",$dir."nspaces.txt");
	print $fh "$totalgeo";
	close($fh);
	open($fh,">:utf8",$dir."ngeocoded.txt");
	print $fh "$totalgeocoded";
	close($fh);
	open($fh,">:utf8",$dir."lastupdated.txt");
	print $fh $ts;
	close($fh);
}




################
# SUBROUTINES
sub getID {
	my $str = $_[0];
	$str = lc($str);
	$str =~ s/[^a-z0-9\-\_]/\_/g;
	return $str;
}

sub parseStorepointFeature {
	my $f = shift;
	my $keys = shift;
	my $json = {'hours'=>{}};
	my @fields = ("title","address","lat","lon","description","accessibility","type");
	my($i,@days,$postcode,$pc);

	for($i = 0; $i < @fields; $i++){
		if($f->{$fields[$i]}){ $json->{$fields[$i]} = $f->{$fields[$i]}; }
		if($keys->{$fields[$i]} && $f->{$keys->{$fields[$i]}}){ $json->{$fields[$i]} = $f->{$keys->{$fields[$i]}}; }
	}

	# Explicit days
	@days = ("monday","tuesday","wednesday","thursday","friday","saturday","sunday");
	$json->{'hours'}{'opening'} = "";
	for($i = 0; $i < @days; $i++){
		if($f->{$days[$i]}){ $json->{'hours'}{$days[$i]} = $f->{$days[$i]}; }
		if($keys->{$days[$i]} && $f->{$keys->{$days[$i]}}){ $json->{'hours'}{$days[$i]} = $f->{$keys->{$days[$i]}}; }
		$json->{'hours'}{$days[$i]} =~ s/(^[\s\t]|[\s\t]$)//g;
	}
	$json->{'hours'} = parseOpeningHours($json->{'hours'});
	if(!$json->{'hours'}{'_text'} && !$json->{'hours'}{'opening'}){
		delete $json->{'hours'};
	}
	
	if($json->{'lon'} < -20){
		if($json->{'address'} =~ /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/){
			$postcode = $2;
			# An unlikely coordinate so try geocoding
			$log->warning("\tUnlikely coordinates ($json->{'lat'}, $json->{'lon'}) so geocoding based on $postcode\n");
			# Now we need to find the postcode areas e.g. LS, BD, M etc and load those files if we haven't
			$pc = getPostcode($postcode);
			if($pc->{'lat'}){
				$json->{'lat'} = $pc->{'lat'};
				$json->{'loc_pcd'} = JSON::XS::true;
			}
			if($pc->{'lon'}){
				$json->{'lon'} = $pc->{'lon'};
				$json->{'loc_pcd'} = JSON::XS::true;
			}
		}
	}

	return $json;
}

sub parseGeoJSONFeature {
	my $f = shift;
	my $keys = shift;
	my $split = shift;
	my $sr = shift;
	my $json = {};
	my @fields = ("title","address","lat","lon","description","accessibility","type","contact","hours");
	my $props = "properties";
	my ($field,$i,@array,$s,$str);
	if(!$f->{$props} && $f->{'attributes'}){
		$props = "attributes";
	}

	# Split fields as necessary
	# split = {"Opening_Times":"[\n\r]+"}
	if(defined($split)){
		foreach $field (keys(%{$split})){
			if(defined($f->{'properties'}{$field})){
				$str = $f->{'properties'}{$field};
				delete $f->{'properties'}{$field};
				@{$f->{'properties'}{$field}} = split(/$split->{$field}/,$str);
			}
		}
	}

	my ($i,@days,$key,$tempk,$v,$k,$partial,@bits,$n,$max);
	for($i = 0; $i < @fields; $i++){
		if($f->{$props}{$fields[$i]}){
			$json->{$fields[$i]} = getProperty($fields[$i],$f->{$props});
		}
		if($keys->{$fields[$i]}){
			$v = getProperty($keys->{$fields[$i]},$f->{$props});
			if($v){ $json->{$fields[$i]} = $v; }
		}
	}

	# Explicit days
	@days = ("monday","tuesday","wednesday","thursday","friday","saturday","sunday");
	for($i = 0; $i < @days; $i++){
		if($f->{$props}{$days[$i]}){ $json->{'hours'}{$days[$i]} = $f->{$props}{$days[$i]}; }
		if($keys->{$days[$i]} && $f->{$props}{$keys->{$days[$i]}}){ $json->{'hours'}{$days[$i]} = $f->{$props}{$keys->{$days[$i]}}; }
	}
	
	# Replacement values
	foreach $key (keys(%{$keys})){
		# Do we have the lookup key
		if($f->{$props}{$keys->{$key}}){
			# Save to the replacement key
			$v = getProperty($keys->{$key},$f->{$props});
			if(ref($v) eq "ARRAY"){
				@bits = @{$v};
				if(@bits > 0){
					$json->{$key} = "";
					for($n = 0; $n < @bits; $n++){
						$bits[$n] =~ s/(^\s|\s$)//;
						$json->{$key} .= ($json->{$key} ? "; ":"").$bits[$n];
					}
				}
			}else{
				$v =~ s/(^\s|\s$)//;
				if($v){ $json->{$key} = $v; }
			}
		}
	}

	foreach $key (keys(%{$keys})){
		if($keys->{$key} =~ /\{\{ ?(.*?) ?\}\}/){
			$partial = $keys->{$key};
			$tempk = $partial;
			$max = 1;
			# First pass to see how many loops we will need
			while($tempk =~ s/\{\{ ?(.*?) ?\}\}//){
				if($split->{$1}){
					$n = @{$f->{$props}{$1}};
					$max = max($max,$n);
				}
			}
			$n = 0;
			$json->{$key} = "";
			# Loop for the number of entries we have and concatenate with a "; "
			for($n = 0; $n < $max; $n++){
				$tempk = $partial;
				while($tempk =~ /\{\{ ?(.*?) ?\}\}/){
					$k = $1;
					$v = getProperty($k,$f->{$props});
					if(ref($v) eq "ARRAY"){
						$v = @{$v}[$n];
					}
					$v =~ s/(^\s|\s$)//;
					$tempk =~ s/\{\{ ?$k ?\}\}/$v/s;
					$tempk =~ s/[\n]/ /g;
				}
				$json->{$key} .= ($json->{$key} ? "; ":"").$tempk;
			}
		}
		$json->{$key} =~ s/\, \,/\,/g;
		# Clean up "<Null>" values
		if($json->{$key} eq "<Null>"){ delete $json->{$key}; }
	}

	# Deal with hours
	if($f->{$props}{'hours'}){ $json->{'hours'} = {'_text'=>$f->{$props}{'hours'} }; }
	if($keys->{'hours'} && $f->{$props}{$keys->{'hours'}}){ $json->{'hours'} = {'_text'=> $f->{$props}{$keys->{'hours'}} }; }

	if($json->{'hours'}){
		if(ref $json->{'hours'} eq ref ""){ $json->{'hours'} = {'_text'=>$json->{'hours'} }; }
		$json->{'hours'} = parseOpeningHours($json->{'hours'});
		if(!$json->{'hours'}{'opening'}){ delete $json->{'hours'}{'opening'}; }
		if(!$json->{'hours'}{'_text'} || $json->{'hours'}{'_text'} eq " "){ delete $json->{'hours'}; }
	}

	# If we haven't explicitly been sent lat/lon in the properties we get it from the coordinates
	if(!$json->{'lat'}){ $json->{'lat'} = ($f->{'geometry'}{'y'}||$f->{'geometry'}{'coordinates'}[1]); }
	if(!$json->{'lon'}){ $json->{'lon'} = ($f->{'geometry'}{'x'}||$f->{'geometry'}{'coordinates'}[0]); }

	if(ref $json->{'lat'} eq "ARRAY" || ref $json->{'lon'} eq "ARRAY"){
		$log->warning("\tCoordinates seem to be an array so calculating centre.\n");
		my (@ll) = getCentre($f->{'geometry'});
		$json->{'lat'} = $ll[1];
		$json->{'lon'} = $ll[0];
	}

	return $json;
}

sub getXLSX {

	my $d = shift;
	my $i = shift;

	my ($file,$str,$t,@strings,$sheet,$props,$row,$col,$attr,$cols,@rows,$rowdata,@geo,@features,$c,$r,$n,$datum);

	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d,$i);
	
	$log->msg("\tUnzipping xlsx to extract data from $d->{'data'}[$i]{'sheet'} (<cyan>$file<none>)\n");

	# First we need to get the sharedStrings.xml
	$str = decode_utf8(join("",`unzip -p $file xl/sharedStrings.xml`));
	while($str =~ s/<si>(.*?)<\/si>//s){
		$t = $1;
		$t =~ s/<[^\>]+>//g;
		push(@strings,$t);
	}	

	$str = decode_utf8(join("",`unzip -p $file xl/worksheets/$d->{'data'}[$i]{'sheet'}.xml`));


	if($str =~ /<sheetData>(.*?)<\/sheetData>/){
		$sheet = $1;
		while($sheet =~ s/<row([^\>]*?)>(.*?)<\/row>//){
			$props = $1;
			$row = $2;
			$attr = {};
			while($props =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
			$rowdata = {'content'=>$row,'attr'=>$attr,'cols'=>()};
			while($row =~ s/<c([^\>]*?)>(.*?)<\/c>//){
				$props = $1;
				$col = $2;
				$col =~ s/<[^\>]+>//g;
				$attr = {};
				while($props =~ s/([^\s]+)="([^\"]+)"//){ $attr->{$1} = $2; }
				if($attr->{'r'} =~ /^([A-Z]+)([0-9]+)/){
					$c = $1;
					$n = $2;
#					if(!$cols->{$c}){ $cols->{$c} = (); }
#					$cols->{$c}[$n-1] = $strings[$col];
					$rowdata->{'cols'}{$c} = $strings[$col];
				}
			}
			push(@rows,$rowdata);
		}
	}

	if($d->{'debug'}){
		$r = @rows;
		$log->msg("\tThere are $r rows in sheet <yellow>$d->{'data'}[$i]{'sheet'}<none>\n");
	}

	for($r = 0; $r < @rows; $r++){
		if($rows[$r]->{'attr'}{'r'} >= $d->{'data'}[$i]{'startrow'}){
			$datum = {};
			foreach $key (keys(%{$d->{'data'}[$i]{'keys'}})){
				if($rows[$r]->{'cols'}{$d->{'data'}[$i]{'keys'}{$key}}){
					$datum->{$key} = $rows[$r]->{'cols'}{$d->{'data'}[$i]{'keys'}{$key}};
				}	
			}
			# Update opening hours
			if(ref($datum->{'hours'}) ne "HASH"){
				$datum->{'hours'} = parseOpeningHours({'_text'=>$datum->{'hours'}});
			}
			
			#if(ref($datum->{'hours'}) BLAH){
			$datum->{'_source'} = $d->{'id'};
			push(@features,$datum);
		}
	}

	# Add lat,lon from postcodes
	return addLatLonFromPostcodes(@features);
}

sub getStorePoint {

	my $d = shift;
	my $i = shift;
	my ($file,$json,$f,$rtnjson,@features);

	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d,$i);

	$log->msg("\tProcessing Storepoint data\n");
	$json = getJSON($file);

	$d->{'count'} = @{$json->{'results'}{'locations'}};
	if($d->{'count'} == 0){
		$log->warning("\tNo features for $d->{'title'}\n");
	}else{

		# For each feature 
		for($f = 0; $f < $d->{'count'}; $f++){
			$rtnjson = parseStorepointFeature($json->{'results'}{'locations'}[$f],$d->{'data'}[$i]{'keys'});
			$rtnjson->{'_source'} = $d->{'id'};
			push(@features,$rtnjson);
		}

		@features = addLatLonFromPostcodes(@features);
	}
	return @features;
}

sub getGeoJSON {

	my $d = shift;
	my $i = shift;

	my ($file,$geojson,$f,$json,@features,$temp);

	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d,$i);

	$log->msg("\tProcessing GeoJSON\n");
	$geojson = getJSON($file);
	
	if(ref $geojson eq "ARRAY"){
		$log->msg("\tGeoJSON looks like an array\n");
		$geojson = $geojson->[0];
	}

	# How many features in the GeoJSON
	$d->{'count'} = @{$geojson->{'features'}};
	if($d->{'count'} == 0){
		$log->warning("\tNo features for $d->{'title'}\n");
	}else{

		# For each feature 
		$d->{'geocount'} = $d->{'count'};
		for($f = 0; $f < $d->{'count'}; $f++){
			$json = parseGeoJSONFeature($geojson->{'features'}[$f],$d->{'data'}[$i]{'keys'},$d->{'data'}[$i]{'split'});
			$json->{'_source'} = $d->{'id'};

			if($d->{'data'}[$i]{'coords'} eq "switch"){
				$temp = $json->{'lon'};
				$json->{'lon'} = $json->{'lat'};
				$json->{'lat'} = $temp;
			}

			if(($geojson->{'crs'} && $geojson->{'crs'}{'properties'}{'name'} =~ /EPSG::27700/) || $d->{'data'}[$i]{'convertFromOSGB'}){
				($json->{'lat'},$json->{'lon'}) = grid_to_ll($json->{'lat'},$json->{'lon'});
			}
			push(@features,$json);
		}
		
		@features = addLatLonFromPostcodes(@features);
	}
	return @features;
}

sub getArcGIS {
	my $d = shift;
	my $i = shift;
	my ($file,$geojson,$f,@features,$json,$sr);

	# Make sure we have the correct output spatial reference
	$sr = "4326";
	if($d->{'data'}[$i]{'spatial-reference'}){ $sr = $d->{'data'}[$i]{'spatial-reference'}; }
	$d->{'data'}[$i]{'url'} =~ s/outSR=[0-9]+/outSR=$sr/g;
	$d->{'data'}[$i]{'url'} =~ s/f=pbf/f=geojson/g;
	
	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d,$i);

	$log->msg("\tProcessing GeoJSON\n");
	$geojson = getJSON($file);

	# How many features in the GeoJSON
	$d->{'count'} = @{$geojson->{'features'}};
	if($d->{'count'} == 0){
		$log->warning("\tNo features for $d->{'title'}\n");
	}else{

		# For each feature 
		$d->{'geocount'} = $d->{'count'};
		for($f = 0; $f < $d->{'count'}; $f++){
			$json = parseGeoJSONFeature($geojson->{'features'}[$f],$d->{'data'}[$i]{'keys'},$d->{'data'}[$i]{'split'});
			if($geojson->{'transform'} && $d->{'data'}[$i]{'transform'} ne "ignore"){
				$json->{'lat'} = $json->{'lat'}*$geojson->{'transform'}{'scale'}[1] + $geojson->{'transform'}{'translate'}[1];
				$json->{'lon'} = $json->{'lon'}*$geojson->{'transform'}{'scale'}[0] + $geojson->{'transform'}{'translate'}[0];
			}
			if($json->{'url'} =~ /^www/){ $json->{'url'} = "http://".$json->{'url'}; }
			$json->{'_source'} = $d->{'id'};
			
			# If our latitude value is implausible but we have EASTING and NORTHING we will try calculating lat,lon from those
			if($json->{'lat'} > 90 && defined $geojson->{'features'}[$f]{'attributes'}{'EASTING'} && defined $geojson->{'features'}[$f]{'attributes'}{'NORTHING'}){
				if($d->{'data'}[$i]{'coordinate-order'} eq "lon-lat"){
					$json->{'lat'} = $geojson->{'features'}[$f]{'attributes'}{'NORTHING'};
					$json->{'lon'} = $geojson->{'features'}[$f]{'attributes'}{'EASTING'};
				}else{
					$json->{'lon'} = $geojson->{'features'}[$f]{'attributes'}{'NORTHING'};
					$json->{'lat'} = $geojson->{'features'}[$f]{'attributes'}{'EASTING'};					
				}
				$geojson->{'crs'} = {'properties'=>{'name'=>'EPSG:27700'}};
			}
			if($geojson->{'crs'} && $geojson->{'crs'}{'properties'}{'name'} =~ /EPSG:+27700/){
				if($d->{'data'}[$i]{'coordinate-order'} eq "lon-lat"){
					($json->{'lat'},$json->{'lon'}) = grid_to_ll($json->{'lon'},$json->{'lat'});					
				}else{
					($json->{'lat'},$json->{'lon'}) = grid_to_ll($json->{'lat'},$json->{'lon'});
				}
			}
			if($json->{'contact'}){
				$json->{'contact'} =~ s/(, )?Email: ?$//g;
				$json->{'contact'} =~ s/Tel: ?$//g;
			}

			delete $json->{'monday'};
			delete $json->{'tuesday'};
			delete $json->{'wednesday'};
			delete $json->{'thursday'};
			delete $json->{'friday'};
			delete $json->{'saturday'};
			delete $json->{'sunday'};

			push(@features,$json);
		}
		@features = addLatLonFromPostcodes(@features);
	}
	return @features;
}

sub cleanCDATA {
	my $str = $_[0];
	$str =~ s/(^<!-?\[CDATA\[|\]\]>$)//g;
	$str =~ s/<!-?\[CDATA\[(.*?)\]\]>/$1/g;
	return $str;
}

sub getGoogleMap {
	
	my $d = shift;
	my $i = shift;

	my ($dir,$str,$file,$kmzfile,$kmzurl,$placemarks,$lon,$lat,$alt,$c,$url,$entry,$props,$remove,$k,@entries,$hrs,$parse,$re,$p2,@matches,$txt,$key,$v,$tempv,@temp,@locs,$loclookup,$l,$tname,$n,$strkmz,$k,@parts,$nparts);

	$url = $d->{'data'}[$i]{'url'};
	$file = $rawdir.$d->{'id'}.($i ? "-$i":"").".html";

	$log->msg("\tGetting Google Maps pageData\n");
	getURLToFile($url,$file);
	$str = join("",getFileContents($file));

	# Try to extract any page data (which may have coordinates not included in the KMZ)
	if($str =~ /var _pageData = \"(.*?)\"\;/){
		$pagedata = $1;
		$pagedata =~ s/\\"/\"/g;
		$pagedata =~ s/\\\"/\"/g;
		eval {
			@temp = @{JSON::XS->new->decode($pagedata)};
		};
		if($@){ error("\tInvalid output in $file.\n"); @temp = (); }
		else {
			# Loop over parts
			for($p = 0; $p < @{$temp[1][6]};$p++){
				@parts = @{$temp[1][6][$p][4]};
				$nparts = @parts;
				if($nparts == 1){
					push(@locs,@{$temp[1][6][0][4][0][6]});
				}else{
					push(@locs,@parts);
				}
			}
			for($l = 0; $l < @locs; $l++){
				$n = @{$locs[$l][4][4]};
				$tname = $locs[$l][5][0][0];
				$tname =~ s/\\u0026/\&/g;	# Replace escaped ampersands
				if($n == 2){
					$loclookup->{$tname} = {'lat'=>$locs[$l][4][4][0],'lon'=>$locs[$l][4][4][1]};
				}
			}
		}
	}
	
	$k = 0;
	while($str =~ s/\"(https:\/\/www.google.com\/maps\/d\/kml\?mid[^\"]+)\\"//){
		$kmzurl = $1;
		$kmzurl =~ s/\\\\u003d/=/g;
		$kmzurl =~ s/\\\\u0026/\&/g;
		$kmzfile = $rawdir.$d->{'id'}."-$k.kmz";
		$k++;

		if($kmzurl =~ /lid=/){
			$log->msg("\tGetting Google Maps kmz from $kmzurl\n");
			getURLToFile($kmzurl,$kmzfile);
			$log->msg("\tUnzipping kmz\n");
			$strkmz = decode_utf8(join("",`unzip -p $kmzfile doc.kml`));

			while($strkmz =~ s/<Placemark>(.*?)<\/Placemark>//s){
				$placemark = $1;
				$entry = {};
				$props = {};
				if($placemark =~ /<name>(.*?)<\/name>/s){ $entry->{'title'} = cleanCDATA($1); }
				#if($placemark =~ /<description>(.*?)<\/description>/s){ $entry->{'description'} = parseText(cleanCDATA($1)); }
				if($placemark =~ /<coordinates>(.*?)<\/coordinates>/s){
					$c = cleanCDATA($1);
					$c =~ s/(^ *| *$)//g;
					$c =~ s/[\n\r\t\s]+//g;
					($lon,$lat,$alt) = split(/,/,$c);
					$entry->{'lat'} = $lat+0;
					$entry->{'lon'} = $lon+0;
				}
				if($placemark =~ /<ExtendedData>(.*?)<\/ExtendedData>/s){
					$parse = cleanCDATA($1);
					while($parse =~ s/<Data name="([^\"]+)">(.*?)<\/Data>//s){
						$k = $1;
						$v = $2;
						if($v =~ s/^.*<value>(.*?)<\/value>.*$/$1/gs){
							$props->{$k} = cleanCDATA($v);
						}
					}
				}
				
				if($placemark =~ /<description>(.*?)<\/description>/s){
					$entry->{'description'} = cleanCDATA($1);
					$remove = {};

					if($placemark !~ /<ExtendedData>(.*?)<\/ExtendedData>/s){
						# Parse properties from description
						while($entry->{'description'} =~ s/([^\>]*?) ?: ?([^\<]*?)(\<|$)/$3/s){
							$props->{$1} = $2;
						}
					}

					if($d->{'data'}[$i]{'parse'}){
						$parse = $d->{'data'}[$i]{'parse'}."";
						@reps = ();
						while($parse =~ s/\{\{ ?([^\}]+) ?\}\}/\(.*?\)/s){
							push(@reps,$1);
						}
						$re = qr/^$parse$/is;
						@matches = $entry->{'description'} =~ $re;
						if(@matches > 0){
							for($p2 = 0; $p2 < @reps; $p2++){
								$reps[$p2] =~ s/(^[\s]+|[\s]+$)//g;
								$txt = parseText($matches[$p2]);
								if($txt && !$props->{$reps[$p2]}){
									$props->{$reps[$p2]} = cleanCDATA($txt);
								}
							}
						}
						$remove{'description'} = 1;
					}
				}

				if($d->{'data'}[$i]{'keys'}){

					# Replace any replacements in the $props structure and add them to the $entry structure
					foreach $key (keys(%{$d->{'data'}[$i]{'keys'}})){
						$v = $d->{'data'}[$i]{'keys'}{$key};
						if($props->{$v}){
							$entry->{$key} = $props->{$v};
						}elsif($v =~ /\{\{ ?(.*?) ?\}\}/){
							$v =~ s/\{\{ ?(.*?) ?\}\}/$props->{$1}/sg;
							$v =~ s/[\n]//g;
							$entry->{$key} = cleanCDATA($v);
						}
					}

					# Build replacements
					foreach $k (keys(%{$d->{'data'}[$i]{'keys'}})){
						if($entry->{$d->{'data'}[$i]{'keys'}{$k}}){
							$entry->{$k} = "".$entry->{$d->{'data'}[$i]{'keys'}{$k}};
							$remove->{$d->{'data'}[$i]{'keys'}{$k}} = 1;
						}
					}
					if(!$entry->{'hours'} && $entry->{$d->{'data'}[$i]{'keys'}{'hours'}}){
						$entry->{'hours'} = $entry->{$d->{'data'}[$i]{'keys'}{'hours'}};
						$entry->{'hours'} =~ s/<br>/ /;
						$entry->{'hours'} =~ s/[\s]/ /;
						$entry->{'hours'} =~ s/[^0-9A-Za-z\-\,\.\:\;\s\[\]]/ /;
						if($d->{'data'}[$i]{'keys'}{'hours'} eq "description"){ $remove{'description'} = 1; }
					}
					$entry->{'description'} = parseText($entry->{'description'});
					if(!$entry->{'description'}){ $remove{'description'}; }
					if($d->{'data'}[$i]{'keys'}{'description'}){
						delete $remove->{'description'};
					}
				}
				foreach $k (keys(%{$remove})){
					delete $entry->{$k};
				}
				if($entry->{'hours'}){
					$entry->{'hours'} = parseOpeningHours({'_text'=>parseText($entry->{'hours'})});
					if(!$entry->{'hours'}{'opening'}){ delete $entry->{'hours'}{'opening'}; }
				}
				
				# If we have built the lookup for the location
				if($loclookup->{$entry->{'title'}}){
					if(!$entry->{'lat'}){ $entry->{'lat'} = $loclookup->{$entry->{'name'}}{'lat'}; }
					if(!$entry->{'lon'}){ $entry->{'lon'} = $loclookup->{$entry->{'name'}}{'lon'}; }
				}else{
					print "No lookup for $entry->{'title'}\n";
				}
				
				$entry->{'_source'} = $d->{'id'};
				push(@entries,$entry);
			}

		}
	}
	
	@entries = addLatLonFromPostcodes(@entries);

	return @entries;
}

sub getSquareSpace {
	my $d = shift;
	my $i = shift;
	my $keys = shift;
	my ($url,$page,$p,@items,$purl,$j,$n,$json,$f,$cache,$attempts);
	my @fields = ("title","address","lat","lon","description","accessibility","type");

	#e.g. https://warmspaces.org/locations?format=json&cache=2022-11-24T00-2
	# Use cache parameter to make sure the pages don't change as we step through them
	$cache = strftime("%FT%H-%M",gmtime);
	$url = $d->{'data'}[$i]{'url'}."?format=json&cache=$cache";

	$p = 1;
	$page = $rawdir.$d->{'id'}."-".($i||"0")."-$p.json";
	getURLToFile($url,$page);
	$json = getJSON($page);
	$attempts = 1;
	
	@items = @{$json->{'items'}};
	
	while($json->{'pagination'}{'nextPage'}){
		$purl = $url."&offset=$json->{'pagination'}{'nextPageOffset'}";
		$p++;
		$page = $rawdir.$d->{'id'}."-".($i||"0")."-$p.json";
		# Get the file but pass in any delay value we already have
		$attempts = getURLToFile($purl,$page,$attempts,2);
		$json = getJSON($page);
		@items = (@items,@{$json->{'items'}});
		$n = @items;
	}
	
	@features;

	for($j = 0; $j < @items; $j++){
			
		$json = {};
		for($f = 0; $f < @fields; $f++){
			if($items[$j]{$fields[$f]}){ $json->{$fields[$f]} = $items[$j]{$fields[$f]}; }
			if($keys->{$fields[$f]} && $items[$j]{$keys->{$fields[$f]}}){ $json->{$fields[$f]} = $items[$j]{$keys->{$fields[$f]}}; }
		}
		$json->{'lat'} = $items[$j]{'location'}{'mapLat'}+0;
		$json->{'lon'} = $items[$j]{'location'}{'mapLng'}+0;
		$json->{'address'} = $items[$j]{'location'}{'addressLine1'}.", ".$items[$j]{'location'}{'addressLine2'};
		if($items[$j]{'excerpt'} =~ /<a href="([^\"]+)">Find out more<\/a>/){ $json->{'url'} = $1; }
		if($items[$j]{'excerpt'} =~ /<strong>(<br>)?Opening Hours: *<\/strong> ?(.*?)</){ $json->{'hours'} = {'_text'=>$2}; }
		$json->{'hours'} = parseOpeningHours($json->{'hours'});

		$json->{'_source'} = $d->{'id'};
		
		push(@features,$json);
	}
	@features = addLatLonFromPostcodes(@features);
	return @features;
}

sub getCSV {
	my $d = shift;
	my $i = shift;

	my ($file,@lines,$str,@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f);
	my @fields = ("title","address","lat","lon","description","accessibility","type","hours");

	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d,$i);


	$log->msg("\tProcessing CSV\n");
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	@rows = split(/\r\n/,$str);
	for($r = 0; $r < @rows; $r++){
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);
		if($r < $d->{'data'}[$i]{'startrow'}-1){
			# Header
			if(!@header){
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					$header[$c] .= "\n".$cols[$c];
				}
			}
		}else{
			if($r == $d->{'data'}[$i]{'startrow'}-1){
				# Process header line - rename columns based on the defined keys
				for($c = 0; $c < @cols; $c++){
					$key = $header[$c];
					foreach $k (keys(%{$d->{'data'}[$i]{'keys'}})){
						if($d->{'data'}[$i]{'keys'}{$k} eq $key){
							$header[$c] = $k;
							last;
						}
					}
				}
			}
			$data = {'_source'=>$d->{'id'}};
			for($c = 0; $c < @cols; $c++){
				$cols[$c] =~ s/(^\"|\"$)//g;
				$needed = 0;
				for($f = 0; $f < @fields; $f++){
					if($header[$c] eq $fields[$f]){ $needed = 1; }
				}
				if($needed){ $data->{$header[$c]} = $cols[$c]; }
				if($header[$c] eq "hours"){ $data->{'hours'} = parseOpeningHours({'_text'=>$cols[$c]}); }
			}
			push(@features,$data);
		}
	}

	# Add lat,lon from postcodes if we don't have them
	return addLatLonFromPostcodes(@features);
}

sub getWPGeoDir {

	my $d = shift;
	my $i = shift;
	
	my ($file,@lines,$str,@features,$f,$url,$json,$jsonmarker,$key,$k,$props,$v,$entry,$remove);

	# Get the data (if we don't have a cached version)
	$file = getDataFromURL($d,$i);

	if(-e $file){
		open(FILE,"<:utf8",$file);
		@lines = <FILE>;
		close(FILE);
		$str = join("",@lines);
		eval {
			$json = JSON::XS->new->decode($str);
		};
		if($@){ $log->warning("\tInvalid output from WordPress GeoDirectory.\n".$str); }
		
		for($f = 0; $f < @{$json->{'items'}}; $f++){
			$entry = {};
			$props = {};
			$remove = {};
			$entry->{'title'} = $json->{'items'}[$f]{'t'};
			$entry->{'lat'} = $json->{'items'}[$f]{'lt'};
			$entry->{'lon'} = $json->{'items'}[$f]{'ln'};
			$url = $d->{'data'}[$i]{'url'};
			$url =~ s/\?.*//g;
			$url .= $json->{'items'}[$f]{'m'};
			$file = $rawdir.$d->{'id'}."-marker-$json->{'items'}[$f]{'m'}.json";
			getURLToFile($url,$file);
			$jsonmarker = getJSON($file);
	
			# Get any properties of the form "Property: blah</div>"
			while($jsonmarker->{'html'} =~ />([^\:\>\<]+)\:(.*?)<\/div>/){
				$props->{$1} = parseText($2);
				$jsonmarker->{'html'} =~ s/>([^\:]+)\:(.*?)<\/div>//;
			}
			if($d->{'data'}[$i]{'keys'}){

				# Replace any replacements in the $props structure and add them to the $entry structure
				foreach $key (keys(%{$d->{'data'}[$i]{'keys'}})){
					$v = $d->{'data'}[$i]{'keys'}{$key};
					if($props->{$v} && !$entry->{$key}){
						$entry->{$key} = $props->{$v};
					}elsif($v =~ /\{\{ ?(.*?) ?\}\}/){
						$v =~ s/\{\{ ?(.*?) ?\}\}/$props->{$1}/sg;
						$v =~ s/[\n]//g;
						$entry->{$key} = cleanCDATA($v);
					}
				}

				# Build replacements
				foreach $k (keys(%{$d->{'data'}[$i]{'keys'}})){
					if($entry->{$d->{'data'}[$i]{'keys'}{$k}}){
						$entry->{$k} = "".$entry->{$d->{'data'}[$i]{'keys'}{$k}};
						$remove->{$d->{'data'}[$i]{'keys'}{$k}} = 1;
					}
				}
				if(!$entry->{'hours'} && $entry->{$d->{'data'}[$i]{'keys'}{'hours'}}){
					$entry->{'hours'} = $entry->{$d->{'data'}[$i]{'keys'}{'hours'}};
					$entry->{'hours'} =~ s/<br>/ /;
					$entry->{'hours'} =~ s/[\s]/ /;
					$entry->{'hours'} =~ s/[^0-9A-Za-z\-\,\.\:\;\s\[\]]/ /;
					if($d->{'data'}[$i]{'keys'}{'hours'} eq "description"){ $remove{'description'} = 1; }
				}
				$entry->{'description'} = parseText($entry->{'description'});
				if(!$entry->{'description'}){ $remove{'description'}; }
				if($d->{'data'}[$i]{'keys'}{'description'}){
					delete $remove->{'description'};
				}
			}
			if($entry->{'hours'}){
				$entry->{'hours'} = parseOpeningHours({'_text'=>$entry->{'hours'}});
			}
			
			push(@features,$entry);
		}
	}

	return @features;
}

sub getHTML {

	my $d = shift;
	my $i = shift;

	my ($scraper,$str,$file,@lines,$json,$f,@features);
	# Find the scraping file
	$scraper = "scrapers/$d->{'id'}.pl";

	if(-e $scraper){

		# Get the data (if we don't have a cached version)
		$file = getDataFromURL($d,$i);

		$log->msg("\tParsing web page using <cyan>$scraper<none> (".(-s $file)." bytes)\n");

		$str = `perl $scraper $file`;


		if(-e $str){
			open(FILE,"<:utf8",$str);
			@lines = <FILE>;
			close(FILE);
			$str = join("",@lines);

			eval {
				$json = JSON::XS->new->decode($str);
			};
			if($@){ $log->warning("\tInvalid output from scraper.\n".$str); }

			for($f = 0; $f < @{$json}; $f++){
				$json->[$f]{'_source'} = $d->{'id'};
				push(@features,$json->[$f]);
			}

			@features = addLatLonFromPostcodes(@features);

		}else{
			$log->warning("\tNo JSON returned from scraper\n");
		}
		if(@features == 0){
			$log->warning("\tNo features found in web page.\n");
		}
	}else{
		$log->error("\tNo scraper at scrapers/$d->{'id'}.pl\n");
		exit;
	}
	return @features;
}
