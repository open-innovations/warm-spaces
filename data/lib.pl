#!/usr/bin/perl

use utf8;
use JSON::XS;

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

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||STDOUT;
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	print $dest $str;
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,STDERR);
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1$colours{'yellow'}WARNING:$colours{'none'} /;
	print STDERR $str;
}

sub getJSON {
	my (@files,$str,@lines);
	my $file = $_[0];
	open(FILE,$file);
	@lines = <FILE>;
	close(FILE);
	$str = decode_utf8(join("",@lines));
	return JSON::XS->new->decode($str);	
}

sub tidyJSON {
	my $json = shift;
	my $depth = shift;
	my $d = $depth+1;
	
	$txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
	$txt =~ s/   /\t/g;
	$txt =~ s/([\{\,\"])\n\t{$d,}([\"\}])/$1 $2/g;
	$txt =~ s/"\n\t{$depth}\}/\" \}/g;
	return $txt;
}

sub makeJSON {
	my $json = shift;
	my $compact = shift;
	
	if($compact){
		$txt = JSON::XS->new->canonical(1)->encode($json);
	}else{
		$txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
		
		$txt =~ s/   /\t/g;

		$txt =~ s/(\t{3}.*)\n/$1/g;
		$txt =~ s/\,\t{3}/\, /g;
		$txt =~ s/\t{2}\}(\,?)\n/ \}$1\n/g;
		$txt =~ s/\{\n\t{3}/\{ /g;
		$txt =~ s/\{\t+\"/\{ \"/g;
		$txt =~ s/\"\t+\}/\" \}/g;
		
		$txt =~ s/\}\,\n\t\{/\},\{/g;
		$txt =~ s/",[\s\t]+"/", "/g;
	}	
	return $txt;
}

# Attempt to parse free-text dates/times into the OSM format https://wiki.openstreetmap.org/wiki/Key:opening_hours
sub parseOpeningHours {
	my $hours = shift;
	my (@days,$parsed,$str,$i,$j,$d,$day1,$day2,$t1,$t2,$ok,$t,$mod1,$mod2);

	@days = (
		{'match'=>['Monday','Mon'],'short'=> 'Mo','key'=>'monday'},
		{'match'=>['Tuesday','Tue','Tues'],'short' => 'Tu','key'=>'tuesday'},
		{'match'=>['Wednesday','Wed'],'short' => 'We','key'=>'wednesday'},
		{'match'=>['Thursday','Thurs','Thur','Thu'],'short' => 'Th','key'=>'thursday'},
		{'match'=>['Friday','Fri'],'short' => 'Fr','key'=>'friday'},
		{'match'=>['Saturday','Sat'],'short' => 'Sa','key'=>'saturday'},
		{'match'=>['Sunday','Sun'],'short' => 'Su','key'=>'sunday'}
	);
	
	# Tidy up any existing times and build parsed string
	$parsed = "";
	for($i = 0; $i < @days; $i++){
		if($hours->{$days[$i]->{'key'}}){
			if($hours->{$days[$i]->{'key'}} =~ /[0-9]/){
				$parsed .= ($parsed ? ", ":"").$days[$i]->{'short'}." ".getHourRange($hours->{$days[$i]->{'key'}});
			}
			$hours->{$days[$i]->{'key'}} =~ s/^[\s\t]+\-[\s\t]+\/[\s\t]+\-[\s\t]+$//g;
			$hours->{$days[$i]->{'key'}} =~ s/[\s\t]+\/[\s\t]+\-[\s\t]+$//g;
			if($hours->{$days[$i]->{'key'}} eq ""){ delete $hours->{$days[$i]->{'key'}}; }

		}
	}
	if($parsed){
		$hours->{'_parsed'} = $parsed;
	}

	$str = "".$hours->{'_text'};
	
	
	if($str && !$hours->{'_parsed'}){


		$str =~ s/ to / - /g;
		$str =~ s/ from /: /g;
		$str =~ s/ (\&|and) /, /g;
		$str =~ s/First ([^\s]+) of the month/$1\[1\]/gi;
		$str =~ s/Second ([^\s]+) of the month/$1\[2\]/gi;
		$str =~ s/Third ([^\s]+) of the month/$1\[3\]/gi;
		$str =~ s/Fourth ([^\s]+) of the month/$1\[4\]/gi;
		$str =~ s/12 ?noon/12am/g;
		$str =~ s/ noon/ 12:00/g;
		$str =~ s/a\.?m\.?/am/g;
		$str =~ s/p\.?m\.?/pm/g;
		$str =~ s/\&apos\;//g;
		$str =~ s/ \&amp\; /, /g;
		$str =~ s/\([^\)]+\)//g;

		for($i = 0; $i < @days; $i++){
			for($j = 0; $j < @{$days[$i]->{'match'}}; $j++){
				$d = $days[$i]->{'match'}[$j];
				$str =~ s/$d[\'s]*(\W|$)/$days[$i]->{'short'}$1/gi;
			}
		}

		# Match day range + time
		while($str =~ s/(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,]\])?[\s\t]*[\-\–][\s\t]*(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,]\])?[\;\:\,]?[\s\t]*([0-9\:\.]+(a\.?m\.?|p\.?m\.?)?[\s\t]*[\-\–][\s\t]*[0-9\:\.]+(a\.?m\.?|p\.?m\.?)?)//i){
			$day1 = $1;
			$mod1 = $2;
			$day2 = $3;
			$mod2 = $4;
			$t = getHourRange($5);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){ $ok = 1; }
				if($ok){
					$hours->{$days[$i]->{'key'}} = $t;
				}
				if($days[$i]->{'short'} eq $day2){ $ok = 0; }			
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1-$day2$mod2 $t";
		}

		# Match time + day range
		while($str =~ s/([0-9\:\.]+(a\.?m\.?|p\.?m\.?)?[\s\t]*[\-\–][\s\t]*[0-9\:\.]+(a\.?m\.?|p\.?m\.?)?)[\s\:\,]*(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,]\])?[\s\t]*[\-\–][\s\t]*(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,]\])?//i){
			$day1 = $4;
			$mod1 = $5;
			$day2 = $6;
			$mod2 = $7;
			$t = getHourRange($1);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){ $ok = 1; }
				if($ok){
					$hours->{$days[$i]->{'key'}} = $t;
				}
				if($days[$i]->{'short'} eq $day2){ $ok = 0; }			
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1-$day2$mod2 $t";
		}

		# Match multiple days with time
		while($str =~ s/(((Mo|Tu|We|Th|Fr|Sa|Su)\,? ?){2,})[\s\t]*[\-\:]*[\s\t]*([0-9\:\.]+(a\.?m\.?|p\.?m\.?)?[\s\t]*[\-\–][\s\t]*[0-9\:\.]+(a\.?m\.?|p\.?m\.?)?)//i){
			$day1 = $1;
			$t = getHourRange($4);
			for($i = 0; $i < @days; $i++){
				if($day1 =~ $days[$i]->{'short'}){
					$hours->{$days[$i]->{'key'}} = $t;
					$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$days[$i]->{'short'} $t";
				}
			}
		}

		# Match single day + time
		while($str =~ s/(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,]\])?[\s\t]*[\;\:\,\-]?[\s\t]*([0-9\:\.]+(a\.?m\.?|p\.?m\.?)?[\s\t]*[\-\–][\s\t]*[0-9\:\.]+(a\.?m\.?|p\.?m\.?)?)//i){
			$day1 = $1;
			$mod1 = $2;
			$t = getHourRange($3);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){
					$hours->{$days[$i]->{'key'}} = $mod1.$t;
				}
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		# Match time + single day
		while($str =~ s/([0-9\:\.]+(a\.?m\.?|p\.?m\.?)?[\s\t]*[\-\–][\s\t]*[0-9\:\.]+(a\.?m\.?|p\.?m\.?)?)[\,]? every *(\[[0-9\,]\])? *(Mo|Tu|We|Th|Fr|Sa|Su)//i){
			$day1 = $3;
			$mod1 = $2;
			$t = getHourRange($1);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){
					$hours->{$days[$i]->{'key'}} = $mod1.$t;
				}
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}
		
		# Match time + single day
		while($str =~ s/([0-9\:\.apm]+[\s\t]*[\-\–][\s\t]*[0-9\:\.apm]+)[\,]? on *(Mo|Tu|We|Th|Fr|Sa|Su)//i){
			$day1 = $3;
			$mod1 = $2;
			$t = getHourRange($1);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){
					$hours->{$days[$i]->{'key'}} = $mod1.$t;
				}
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		# Match "Daily"
		while($str =~ s/(Daily|7 days (a|per) week)(\[[0-9\,]\])?[\;\:\,]?[\s\t]*([0-9\:\.apm]+[\s\t]*[\-\–][\s\t]*[0-9\:\.apm]+)//i){
			$day1 = "Mo-Su";
			$mod1 = $2;
			$t = getHourRange($3);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){
					$hours->{$days[$i]->{'key'}} = $mod1.$t;
				}
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		# Match "Daily"
		while($str =~ s/([0-9\:\.apm]+[\s\t]*[\-\–][\s\t]*[0-9\:\.apm]+)[\s\t\,]*(Daily|7 days (a|per) week)//i){
			$day1 = "Mo-Su";
			$t = getHourRange($1);
			$ok = 0;
			for($i = 0; $i < @days; $i++){
				if($days[$i]->{'short'} eq $day1){
					$hours->{$days[$i]->{'key'}} = $mod1.$t;
				}
			}
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		if(!$hours->{'_parsed'}){
			warning("\tCan't parse hours from \"$hours->{'_text'}\"\n");
		}

	}

	return $hours;
}

sub getHourRange {
	my $str = $_[0];
	my ($t1,$t2) = split(/ ?[\-\–] ?/,$str);
	return niceHours($t1)."-".niceHours($t2);
}

sub niceHours {
	my $str = $_[0];
	my ($am,$pm,$hh,$mm);
	$am = 0;
	$pm = 0;
	if($str =~ s/am//g){ $am = 1; }
	if($str =~ s/pm//g){ $pm = 1; }
	if($str =~ /[\:\.]/){
		($hh,$mm) = split(/[\:\.]/,$str);
	}else{
		$hh = $str+0;
		$mm = 0;
	}
	if($pm){
		$hh += 12;
		# Correction for people using 12:30pm to mean afternoon
		if($hh >= 24){ $hh -= 12; }
	}
	return sprintf("%02d:%02d",$hh,$mm);
}

1;