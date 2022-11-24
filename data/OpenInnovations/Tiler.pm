# ============
# Tiler v0.1
package OpenInnovations::Tiler;

use strict;
use warnings;
use Data::Dumper;
use List::Util qw( min max );
use Math::Trig;
use constant PI => 4 * atan2(1, 1);
use constant X         => 0;
use constant Y         => 1;
use constant TWOPI     => 2 * PI;
use constant R         => 6378137;
use constant SPHERICALSCALE => 0.5 / (PI * R);
use constant D2R       => PI / 180;
use constant R2D       => 180 / PI;
# Approximate conversion from degrees of latitude to metres
# Assumes a spherical Earth which is probably good enough for these purposes.
use constant deg2m => 6371000 * 2 * PI / 360;


sub new {
    my ($class, %args) = @_;
 
    my $self = \%args;
 
    bless $self, $class;
 
    return $self;
}

sub tile2lon {
	my $x = $_[0];
	my $z = $_[1];
	return ($x / (2**$z)*360 - 180);
}

sub tile2lat {
	my $y = $_[0];
	my $z = $_[1];
	my $n = PI - 2 * PI * $y/(2**$z);
	return (180/PI * atan(0.5*(exp($n)-exp(-$n))));
}

sub tiled {
	return int($_[0]/256);
}

# Adapts a group of functions from Leaflet.js to work headlessly
# https://github.com/Leaflet/Leaflet
sub project {
	my ($self, $lat, $lng, $zoom) = @_;
	my $max = 1 - 1e-15;
	my $sin = max(min(sin($lat * D2R),$max),-$max);
	my $scale = 256 * 2**$zoom;
	my $x = tiled($scale * (SPHERICALSCALE * (R * $lng * D2R) + 0.5));
	my $y = tiled($scale * (-1 * SPHERICALSCALE * (R * log((1 + $sin) / (1 - $sin)) / 2) + 0.5));
	return ($x,$y);
}

# Adapted from: https://gist.github.com/mourner/8825883 */
sub xyz {
	my ($self, %bounds) = @_;

	my $z = $bounds{'zoom'};

	#print "zoom = $z\n";
	#print "NE lat = $bounds{'NE'}{'lat'}\n";
	my @min = $self->project($bounds{'NE'}{'lat'},$bounds{'SW'}{'lng'},$z);	# north,west
	my @max = $self->project($bounds{'SW'}{'lat'},$bounds{'NE'}{'lng'},$z);	# south,east

	#print Dumper @min;
	#print Dumper @max;
	
	my @tiles;
	my ($x,$y);
	for($x = $min[0]; $x <= $max[0]; $x++){
		for($y = $min[1]; $y <= $max[1]; $y++){
			push(@tiles,{
				'x'=> $x,
				'y'=> $y,
				'z'=> $z,
				'NE'=>{'lat'=>tile2lat($y,$z),'lng'=>tile2lon($x+1,$z)},
				'SW'=>{'lat'=>tile2lat($y+1,$z),'lng'=>tile2lon($x,$z)}
			});
		}
	}
	return @tiles;
	
}


1;