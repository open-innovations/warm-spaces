#!/usr/bin/perl
# A script to parse OS Open Names files (converted to TSV for speed)
# and create a set of files by first letter of the name

use Geo::Coordinates::OSGB qw(ll_to_grid grid_to_ll);
use Data::Dumper;
binmode STDOUT, 'utf8';

$dir = $ARGV[0];

if(!-d $dir){
	print "Please provide a path to OS Open Names DATA directory\n";
	exit;
}

$sortby = 'size';
$order = "reverse";

@bounds = ([45,-8],[65,2]);

$types = {
	'City'=>{'key'=>'c','size'=>10},
	'Town'=>{'key'=>'t','size'=>8},
	'Village'=>{'key'=>'v','size'=>4},
	'Hamlet'=>{'key'=>'h','size'=>3},
	'Other Settlement'=>{'key'=>'o','size'=>2},
	'Suburban Area'=>{'key'=>'a','size'=>7}
};
%postcodes;

opendir(my $dh, $dir);
@filenames = sort readdir( $dh );
closedir $dh;

@places;

for($f = 0; $f < @filenames; $f++){
	$file = $filenames[$f];
	$ok = 1;
	
	if($ok){
		print "Processing $dir$file\n";
		open($fh,"<:utf8",$dir.$file);
		while($line = <$fh>){
			# It is quicker to parse 
			if($file =~ /\.tsv/){
				(@cols) = split(/\t/,$line);
			}else{
				(@cols) = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$line);
			}
			$pcd = 0;
			if($cols[7] eq "Postcode" && $cols[2] =~ /^([^\s]+)/){
				$pcd = $1;
				if($pcd && $postcodes{$pcd}){
					# Don't bother keeping it if we already have it
					$pcd = "";
				}
			}
			# Get coordinates
			if(($cols[6] eq "populatedPlace" && $types->{$cols[7]}) || $pcd){
				($lat,$lon) = grid_to_ll($cols[8],$cols[9]);
				$lat += 0;
				$lon += 0;
				if($lat >= $bounds[0][0] && $lat <= $bounds[1][0] && $lon >= $bounds[0][1] && $lon <= $bounds[1][1]){
					$key = $cols[2].",".$cols[24].",".$cols[21].",".$cols[16];
					if($pcd && !$postcodes{$pcd}){
						print "Adding postcode district $pcd at $lat,$lon\n";
						$postcodes{$pcd} = {'latitude'=>sprintf("%0.4f",$lat)+0,'longitude'=>sprintf("%0.4f",$lon)+0,'ref'=>$file,'name'=>$pcd,'admin name'=>($cols[21]||$cols[24]),'type'=>$types->{$cols[7]}{'key'},'size'=>5};
						push(@places,$postcodes{$pcd});
					}else{
						push(@places,{'latitude'=>sprintf("%0.4f",$lat)+0,'longitude'=>sprintf("%0.4f",$lon)+0,'ref'=>$file,'name'=>$cols[2],'admin name'=>($cols[21]||$cols[24]),'type'=>$types->{$cols[7]}{'key'},'size'=>$types->{$cols[7]}{'size'}});
					}
					$n = @places;
					if($n%1000==0){
						print "\t\t$n places\n";
					}
				}
			}
		}
		close($fh);
	}
}

@result = orderit(@places);

%letters;

for($i = 0; $i < @result; $i++){
	$letter = lc(substr($result[$i]->{'name'},0,1));
	if(!$letters{$letter}){ $letters{$letter} = (); }
	push(@{$letters{$letter}},"$result[$i]->{'name'}\t".($result[$i]->{'admin name'} ne $result[$i]->{'name'} ? $result[$i]->{'admin name'} : "")."\t$result[$i]->{'type'}\t$result[$i]->{'latitude'}\t$result[$i]->{'longitude'}");
}

foreach $letter (sort(keys(%letters))){
	print "$letter\n";
	open(FILE,">:utf8","../../docs/data/geo/ranked-$letter.tsv");
	for($i = 0; $i < @{$letters{$letter}}; $i++){
		print FILE $letters{$letter}[$i]."\n";
	}
	close(FILE);
}
$n = @result;
print $n."\n";



sub orderit {
	my @in = @_;
	my @sorted = ($in[0]->{$column} =~ /[a-zA-Z]/) ? (sort { lc($a->{$sortby}) cmp lc($b->{$sortby}) } @in) : (sort { $a->{$sortby} <=> $b->{$sortby} } @in);
	if($order eq "reverse"){ @sorted = reverse(@sorted); }
	return @sorted;
}


