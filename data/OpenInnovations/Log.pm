# ============
# Logging v0.2
package OpenInnovations::Log;

use utf8;
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';
use Data::Dumper;
#use strict;
use warnings;

my $fh;
my %colours = (
	'black'=>"\033[0;30m",
	'red'=>"\033[0;31m",
	'green'=>"\033[0;32m",
	'yellow'=>"\033[0;33m",
	'blue'=>"\033[0;34m",
	'magenta'=>"\033[0;35m",
	'cyan'=>"\033[0;36m",
	'white'=>"\033[0;37m",
	'none'=>"\033[0m"
);

sub new {
    my ($class, %args) = @_;
 
    my $self = \%args;
	
	if($self->{'file'}){
		$self->open($self->{'file'});
	}
 
    bless $self, $class;
 
    return $self;
}

sub open {
	my ($self,$file) = @_;
	open($fh,">utf8",$file);
	return $self;
}

sub close {
	my ($self) = @_;

	if(defined $fh){
		close($fh);
	}
	return $self;
}


sub msg {
	my ($self,$str,$dest) = @_;
	if(!defined $dest){
		$dest = STDOUT;
	}
	my $ostr = $str;
	foreach my $c (keys(%colours)){
		$str =~ s/\< ?$c ?\>/$colours{$c}/g;
		$ostr =~ s/\< ?$c ?\>//g;
	}
	print $dest $str;
	if(defined $fh){
		print $fh $ostr;
	}
	return $self;
}

sub error {
	my ($self,$str) = @_;
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	my $ostr = $str;
	foreach my $c (keys(%colours)){
		$str =~ s/\< ?$c ?\>/$colours{$c}/g;
		$ostr =~ s/\< ?$c ?\>//g;
	}
	print STDERR $str;
	if(defined $fh){
		print $fh $ostr;
	}
	return $self;
}

sub warning {
	my ($self,$str) = @_;
	$str =~ s/(^[\t\s]*)/$1<yellow>WARNING:<none> /;
	my $ostr = $str;
	foreach my $c (keys(%colours)){
		$str =~ s/\< ?$c ?\>/$colours{$c}/g;
		$ostr =~ s/\< ?$c ?\>//g;
	}
	print STDERR $str;
	if(defined $fh){
		print $fh $ostr;
	}
	return $self;
}


1;