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
	if(!$str){ $str = "{}"; }
	return JSON::XS->new->decode($str);	
}

sub tidyJSON {
	my $json = shift;
	my $depth = shift;
	my $d = $depth+1;
	
	$txt = JSON::XS->new->canonical(1)->pretty->space_before(0)->encode($json);
	$txt =~ s/   /\t/g;
	$txt =~ s/([\{\,\"])\n\t{$d,}([\"\}])/$1 $2/g;
	$txt =~ s/"\n\t{$depth,}\}/\" \}/g;
	$txt =~ s/null\n\t{$depth,}\}/null \}/g;

	# Kludge to fix validation white space issues with warm_spaces entries
	while($txt =~ s/("description": "[^\"]*)[	]([^\"]*")/$1 $2/g){}
	while($txt =~ s/("address": "[^\"]*)[	]([^\"]*")/$1 $2/g){}
	while($txt =~ s/("title": "[^\"]*)[	]([^\"]*")/$1 $2/g){}
	while($txt =~ s/("url": "[^\"]*)[	]([^\"]*")/$1 $2/g){}
	while($txt =~ s/("accessibility": "[^\"]*)[	]([^\"]*")/$1 $2/g){}
	while($txt =~ s/("_text": "[^\"]*)[	]([^\"]*")/$1 $2/g){}
	$txt =~ s/\"\*\*/\"/g;
	$txt =~ s/  \"/\"/g;
	$txt =~ s/	 / /g;
	$txt =~ s/ / /g;
	$txt =~ s/ {2,}/ /g;

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
	my (@days,$parsed,$str,$i,$j,$d,$day1,$day2,$t1,$t2,$ok,$t,$mod1,$mod2,$nstr,$nth);

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
			$hours->{$days[$i]->{'key'}} =~ s/^[\s\t]+\-[\s\t]+\/[\s\t]+//g;
			if($hours->{$days[$i]->{'key'}} eq ""){ delete $hours->{$days[$i]->{'key'}}; }

		}
	}
	if($parsed){
		$hours->{'_parsed'} = $parsed;
	}

	$str = "".$hours->{'_text'};
	
	
	if($str && !$hours->{'_parsed'}){


		$str =~ s/ at [^0-9]+ from /: /g;
		$str =~ s/ to / - /g;
		$str =~ s/ from /: /g;
		$str =~ s/ (\&|and) /, /g;
		$str =~ s/\&apos\;//g;
		$str =~ s/ \&amp\; /, /g;
		$str =~ s/ ?\([^\)]+\)//g;

		# Convert "weekdays" or "weekends" into day ranges
		$str =~ s/Weekdays/Mo-Fr/gi;
		$str =~ s/Weekends/Sa-Su/gi;

		# Convert "noon" values to numbers
		$str =~ s/12 ?noon/12am/g;
		$str =~ s/noon/ 12:00/g;

		# Standardise A.M./P.M./a.m./p.m./AM/PM into am/pm
		$str =~ s/a\.?m\.?/am/gi;
		$str =~ s/p\.?m\.?/pm/gi;


		for($i = 0; $i < @days; $i++){
			for($j = 0; $j < @{$days[$i]->{'match'}}; $j++){
				$d = $days[$i]->{'match'}[$j];
			
				# Replace any string that refers to e.g. "first Sunday" with "Su[1]"
				while($str =~ /((first|First|second|Second|third|Third|fourth|Fourth|last|Last|and|\,|\s)+) $d( of the month)?/){
					$nth = $1;
					$nstr = "";
					if($nth =~ /first/i){ $nstr .= ($nstr?",":"")."1"; }
					if($nth =~ /second/i){ $nstr .= ($nstr?",":"")."2"; }
					if($nth =~ /third/i){ $nstr .= ($nstr?",":"")."3"; }
					if($nth =~ /fourth/i){ $nstr .= ($nstr?",":"")."4"; }
					if($nth =~ /last/i){ $nstr .= ($nstr?",":"")."-1"; }
					if($nstr){ $nstr = " $days[$i]->{'short'}\[$nstr\]"; }
					else { $nstr = " ".$d; }
					$str =~ s/((first|First|second|Second|third|Third|fourth|Fourth|last|Last|and|\,|\s)+) $d( of (the|each) month)?/$nstr/;
				}				

				# Replace a day match with the short version
				$str =~ s/$d[\'s]*(\W|$)/$days[$i]->{'short'}$1/gi;
			}
		}

		# Match day range + time
		while($str =~ s/(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,\-]\])?[\s\t]*[\-\–][\s\t]*(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,]\])?[\;\:\,]?[\s\t]*([0-9\:\.\,apm\s\t\-]+)//){
			$day1 = $1;
			$mod1 = $2;
			$day2 = $3;
			$mod2 = $4;
			$t = getHourRange($5);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1-$day2$mod2 $t";
		}

		# Match time + day range
		while($str =~ s/([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)[\s\:\,]*(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,\-]\])?[\s\t]*[\-\–][\s\t]*(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,\-]\])?//){
			$day1 = $4;
			$mod1 = $5;
			$day2 = $6;
			$mod2 = $7;
			$t = getHourRange($1);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1-$day2$mod2 $t";
		}

		# Match multiple days with time
		while($str =~ s/(((Mo|Tu|We|Th|Fr|Sa|Su)\,? ?){2,})[\s\t]*[\-\:]*[\s\t]*([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)//){
			$day1 = $1;
			$t = getHourRange($4);
			for($i = 0; $i < @days; $i++){
				if($day1 =~ $days[$i]->{'short'}){
					$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$days[$i]->{'short'} $t";
				}
			}
		}

		# Match single day + time
		while($str =~ s/(Mo|Tu|We|Th|Fr|Sa|Su)(\[[0-9\,\-]+\])?[\s\t]*[\;\:\,\-]?[\s\t]*([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)//){
			$day1 = $1;
			$mod1 = $2;
			$t = getHourRange($3);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		# Match time + "every" + single day
		while($str =~ s/([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)[\,]? every *(\[[0-9\,\-]\])? *(Mo|Tu|We|Th|Fr|Sa|Su)//){
			$day1 = $3;
			$mod1 = $2;
			$t = getHourRange($1);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}
		
		# Match time + "on" + single day
		while($str =~ s/([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)[\,]? on *(Mo|Tu|We|Th|Fr|Sa|Su)//){
			$day1 = $4;
			$t = getHourRange($1);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1 $t";
		}

		# Match "Daily"
		while($str =~ s/(Daily|7 days (a|per) week)(\[[0-9\,\-]\])?[\;\:\,]?[\s\t]*([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)//i){
			$day1 = "Mo-Su";
			$mod1 = $2;
			$t = getHourRange($3);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		# Match "Daily"
		while($str =~ s/([0-9\:\.\,]+(am|pm)?[\s\t]*[\-\–][\s\t]*[0-9\:\.\,]+(am|pm)?)[\s\t\,]*(Daily|7 days (a|per) week)//i){
			$day1 = "Mo-Su";
			$t = getHourRange($1);
			$hours->{'_parsed'} .= ($hours->{'_parsed'} ? "; ":"")."$day1$mod1 $t";
		}

		if(!$hours->{'_parsed'}){
			warning("\tCan't parse hours from \"$hours->{'_text'}\"\n");
		}
	}
	
	# Now delete individual days but add them to a '_text' string
	if(!$hours->{'_text'}){
		$hours->{'_text'} = "";
		for($i = 0; $i < @days; $i++){
			$hours->{$days[$i]{'key'}} =~ s/(\-[\s\t]*\/[\s\t]*\-)//g;
			$hours->{$days[$i]{'key'}} =~ s/(^[\s\t]+|[\s\t]+$)//g;
			if(!($hours->{$days[$i]{'key'}} eq "-" || $hours->{$days[$i]{'key'}} eq "")){
				$hours->{'_text'} .= ($hours->{'_text'} ? ", ":"").$days[$i]{'key'}.": ".$hours->{$days[$i]{'key'}};
			}
			delete $hours->{$days[$i]{'key'}};
		}
	}

	$hours->{'opening'} = $hours->{'_parsed'};
	delete $hours->{'_parsed'};
	return $hours;
}

sub getHourRange {
	my $str = $_[0];
	my ($t1,$t2,@times,$t,$out);
	@times = split(/\,/,$str);
	$out = "";
	for($t = 0; $t < @times; $t++){
		($t1,$t2) = split(/ ?[\-\–] ?/,$times[$t]);
		$out .= ($out?",":"").niceHours($t1)."-".niceHours($t2);
	}
	return $out;
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
		$mm = substr($mm,0,2);	# Truncate to two digits (sometimes people mistype an extra digit)
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