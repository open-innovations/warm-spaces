#!/usr/bin/perl

my $basedir;
BEGIN {
	$basedir = $0;
	$basedir =~ s/[^\/]*$//g;
	if(!$basedir){ $basedir = "./"; }
	$lib = $basedir."";
}
use lib $lib;
use OpenInnovations::ColourScale;
use utf8;
use JSON::XS;
use Data::Dumper;
use POSIX qw(strftime);
use Encode;
use Math::Trig;
use constant PI => 4 * atan2(1, 1);
use constant X         => 0;
use constant Y         => 1;
use constant TWOPI    => 2*PI;
require "lib.pl";
binmode STDOUT, 'utf8';


# Define a colour scale object
$cs = OpenInnovations::ColourScale->new();

# Load the constituency polygons
@features = loadFeatures($basedir."temp/Westminster_Parliamentary_Constituencies_(Dec_2021)_UK_BGC.geojson");
$nf = @features;

# Load the IMD values
$imd = getCSV($basedir."temp/constituency_imd.csv","gss-code");

# Load the warm spaces
$json = getJSON($basedir."../docs/data/places.json");
@places = @{$json};

@lines = getFileContents($basedir."../docs/data/ndirs.txt");
$ndir = $lines[0];


%pcon;
$min = 0;
$max = 0;
for($i = 0; $i < @places; $i++){
	if($places[$i]{'lat'} && $places[$i]{'lon'}){
		#print "$i = $places[$i]{'lat'},$places[$i]{'lon'}\n";
		$id = getFeature("PCON21CD",$places[$i]{'lat'},$places[$i]{'lon'},@features);
		#print "$i - $id = $imd->{$id}{'pcon-imd-pop-decile'}\n";
		if(!$pcon{$id}){ $pcon{$id} = 0; }
		$pcon{$id}++;
		if($pcon{$id} > $max){ $max = $pcon{$id}; }
	}
}

print "$ndir\n";

# Make the SVG
$n = 10;
$decade = $nf/$n;
$fs = 16;
$pad = $fs;
$colwidth = 6*$fs;
$rowheight = $fs;
$gap = $fs*0.125;
$head = $fs*2;
$subhead = $fs*1.5;
$foot = $fs;
$sides = 0;
$width = $pad + $sides + $n * $colwidth + ($n-1) * $gap + $sides + $pad;
$height = $pad + $head + $subhead + $pad + ($decade+1) * $rowheight + (($decade) * $gap) + $foot + $pad;
$svg = "<svg version=\"1.1\" viewBox=\"0 0 $width $height\" width=\"$width\" height=\"$height\" xmlns=\"http://www.w3.org/2000/svg\">\n";
# Add title
$svg .= "<text x=\"".($width/2)."\" y=\"".($pad + $head/2)."\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"Poppins, Arial Black\" font-weight=\"bold\" font-size=\"".($fs*1.2)."\">Number of warm spaces vs IMD 2020</text>";
$svg .= "<text x=\"".($width/2)."\" y=\"".($pad + $head + $subhead/2)."\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"Poppins, Arial Black\" font-size=\"".($fs)."\">From most deprived (1) to least deprived (10)</text>";
$svg .= "<text x=\"".($pad + $sides)."\" y=\"".($height - $pad - $foot/2)."\" text-anchor=\"start\" dominant-baseline=\"middle\" font-family=\"Poppins, Arial Black\" font-size=\"".($fs*0.75)."\">Data from $ndir warm spaces directories; IMD scores from MySociety; Constituency boundaries from ONS</text>";
$svg .= "<text x=\"".($width - $pad - $sides)."\" y=\"".($height - $pad - $foot/2)."\" text-anchor=\"end\" dominant-baseline=\"middle\" font-family=\"Poppins, Arial Black\" font-size=\"".($fs*0.75)."\">© Open Innovations (CC-BY)</text>";
for($i = 1; $i <= $n; $i++){
	$x = $pad + $sides + ($i-0.5)*$colwidth + ($i-1)*$gap;
	$y = $pad + $head + $subhead + $pad + $rowheight/2;
	$svg .= "<text x=\"$x\" y=\"$y\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"Poppins, Arial Black\" font-weight=\"bold\" font-size=\"$fs\">$i</text>";
}
$i = 0;
foreach $id (sort{ $imd->{$b}{'pcon-deprivation-score'} <=> $imd->{$a}{'pcon-deprivation-score'} }(keys(%{$imd}))){
	$decile = int($i/$decade)+1;
	$j = ($i - ($decile-1)*$decade) + 1;
	$x = $pad + $sides + ($decile-1)*$colwidth + ($decile-2)*$gap;
	$y = $pad + $head + $subhead + $pad + $j*$rowheight + ($j-1)*$gap;
	$colour = $cs->getColourFromScale('Viridis',$pcon{$id},$min,$max);
	$svg .= "<rect x=\"$x\" y=\"$y\" width=\"$colwidth\" height=\"$rowheight\" fill=\"$colour\"><title>".$imd->{$id}{'constituency-name'}.": ".($pcon{$id}||"0")."</title></rect>\n";
	$i++;
}
$svg .= "</svg>";
open(FILE,">:utf8","imd.svg");
print FILE $svg;
close(FILE);


####################

sub getCSV {
	my $file = shift;
	my $col = shift;

	my (@lines,$str,@rows,@cols,@header,$r,$c,@features,$data,$key,$k,$f);

	msg("Processing CSV from <cyan>$file<none>\n");
	open(FILE,"<:utf8",$file);
	@lines = <FILE>;
	close(FILE);
	$str = join("",@lines);
	@rows = split(/[\r\n]+/,$str);

	for($r = 0; $r < @rows; $r++){
		@cols = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$rows[$r]);
		if($r < 1){
			# Header
			if(!@header){
				@header = @cols;
			}else{
				for($c = 0; $c < @cols; $c++){
					$header[$c] .= "\n".$cols[$c];
				}
			}
		}else{
			$data = {};
			for($c = 0; $c < @cols; $c++){
				$cols[$c] =~ s/(^\"|\"$)//g;
				$data->{$header[$c]} = $cols[$c];
			}
			push(@features,$data);
		}
	}
	if($col){
		$data = {};
		for($r = 0; $r < @features; $r++){
			$data->{$features[$r]->{$col}} = $features[$r];
		}
		return $data;
	}else{
		return @features;
	}
}
sub loadFeatures {
	my $file = $_[0];
	my (@lines,$str,$coder,$json,@features,$f,$minlat,$maxlat,$minlon,$maxlon,@gs,$n);

	# Create a JSON parser
	$coder = JSON::XS->new->utf8->canonical(1);

	if(-e $file){
		msg("Reading GeoJSON file from <cyan>$file<none>\n");
		open(FILE,$file);
		@lines = <FILE>;
		close(FILE);
	}else{
		error("Unable to open $file\n");
		return ();
	}
	

	$str = join("",@lines);
	$json = $coder->decode($str);
	@features = @{$json->{'features'}};
	# Loop over features and add rough bounding box
	for($f = 0; $f < @features; $f++){
		$minlat = 90;
		$maxlat = -90;
		$minlon = 180;
		$maxlon = -180;
		if($features[$f]->{'geometry'}->{'type'} eq "Polygon"){
			($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$features[$f]->{'geometry'}->{'coordinates'}});
			# Set the bounding box
			$features[$f]->{'geometry'}{'bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
		}elsif($features[$f]->{'geometry'}->{'type'} eq "MultiPolygon"){
			$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
			for($p = 0; $p < $n; $p++){
				($minlat,$maxlat,$minlon,$maxlon) = getBBox($minlat,$maxlat,$minlon,$maxlon,@{$features[$f]->{'geometry'}->{'coordinates'}[$p]});
			}
			# Set the bounding box
			$features[$f]->{'geometry'}{'bbox'} = {'lat'=>{'min'=>$minlat,'max'=>$maxlat},'lon'=>{'min'=>$minlon,'max'=>$maxlon}};
		}else{
			#print "ERROR: Unknown geometry type $features[$f]->{'geometry'}->{'type'}\n";
		}

	}
	return @features;
}

sub getBBox {
	my @gs = @_;
	my ($minlat,$maxlat,$minlon,$maxlon,$n,$i);
	$minlat = shift(@gs);
	$maxlat = shift(@gs);
	$minlon = shift(@gs);
	$maxlon = shift(@gs);
	$n = @{$gs[0]};

	for($i = 0; $i < $n; $i++){
		if($gs[0][$i][0] < $minlon){ $minlon = $gs[0][$i][0]; }
		if($gs[0][$i][0] > $maxlon){ $maxlon = $gs[0][$i][0]; }
		if($gs[0][$i][1] < $minlat){ $minlat = $gs[0][$i][1]; }
		if($gs[0][$i][1] > $maxlat){ $maxlat = $gs[0][$i][1]; }
	}
	return ($minlat,$maxlat,$minlon,$maxlon);
}
sub rad {
	return $_[0] * pi() / 180;
}


sub mapAdjPairs (&@) {
    my $code = shift;
    map { local ($a, $b) = (shift, $_[0]); $code->() } 0 .. @_-2;
}

sub Angle{
    my ($x1, $y1, $x2, $y2) = @_;
    my $dtheta = atan2($y1, $x1) - atan2($y2, $x2);
    $dtheta -= TWOPI while $dtheta >   PI;
    $dtheta += TWOPI while $dtheta < - PI;
    return $dtheta;
}

sub PtInPoly{
    my ($poly, $pt) = @_;
    my $angle=0;

    mapAdjPairs{
        $angle += Angle(
            $a->[X] - $pt->[X],
            $a->[Y] - $pt->[Y],
            $b->[X] - $pt->[X],
            $b->[Y] - $pt->[Y]
        )
    } @$poly, $poly->[0];

    return !(abs($angle) < PI);
}

sub getFeature {
	my $key = shift(@_);
	my $lat = shift(@_);
	my $lon = shift(@_);
	my @features = @_;
	
	my ($f,$n,$ok,@gs);
	for($f = 0; $f < @features; $f++){
		$ok = 0;

		# Use pre-computed bounding box to do a first cut - this makes things a lot quicker
		if($lat >= $features[$f]->{'geometry'}{'bbox'}{'lat'}{'min'} && $lat <= $features[$f]->{'geometry'}{'bbox'}{'lat'}{'max'} && $lon >= $features[$f]->{'geometry'}{'bbox'}{'lon'}{'min'} && $lon <= $features[$f]->{'geometry'}{'bbox'}{'lon'}{'max'}){

			# Is this a Polygon?
			if($features[$f]->{'geometry'}->{'type'} eq "Polygon"){

				@gs = @{$features[$f]->{'geometry'}->{'coordinates'}[0]};
				$ok = withinPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});

			}elsif($features[$f]->{'geometry'}->{'type'} eq "MultiPolygon"){

				$n = @{$features[$f]->{'geometry'}->{'coordinates'}};
				$ok = withinMultiPolygon($lat,$lon,@{$features[$f]->{'geometry'}->{'coordinates'}});

			}
			if($ok){
				return $features[$f]->{'properties'}{$key||'msoa11cd'};
			}
		}
	}
	return "";
}

sub withinMultiPolygon {
	my @gs = @_;
	my ($lat,$lon,$p,$n,$ok);
	$lat = shift(@gs);
	$lon = shift(@gs);
	$n = @gs;

	for($p = 0; $p < $n; $p++){
		if(withinPolygon($lat,$lon,@{$gs[$p]})){
			return 1;
		}
	}
	return 0;
}

sub withinPolygon {
	my @gs = @_;
	my ($lat,$lon,$p,$n,$ok,$hole);
	$lat = shift(@gs);
	$lon = shift(@gs);
	$ok = 0;
	$n = @gs;

	$ok = (PtInPoly( \@{$gs[0]}, [$lon,$lat]) ? 1 : 0);

	if($ok){
		if($n > 1){
			#print "Check if in hole\n";
			for($p = 1; $p < $n; $p++){
				$hole = (PtInPoly( \@{$gs[$p]}, [$lon,$lat]) ? 1 : 0);
				if($hole){
					return 0;
				}
			}
		}
		return 1;
	}

	return 0;
}
