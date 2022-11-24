#!/usr/bin/perl

use lib "./";
use utf8;
use JSON::XS;
use YAML::XS 'LoadFile';
use Encode;
use Data::Dumper;
require "lib.pl";
binmode STDOUT, 'utf8';


@tests = (
	{'text'=>'Monday: 1pm - 5pm, Wednesday: 9.30am - 4pm','good'=>'Mo 13:00-17:00; We 09:30-16:00'},
	{'text'=>'&lsquo;Soup Socials&rsquo; will operate from noon to 2pm on Mondays.','good'=>'Mo 12:00-14:00'},
	{'text'=>'Open 10am to 6pm, 7 days a week','good'=>'Mo-Su 10:00-18:00'},
	{'text'=>'Sundays 12noon-4pm','good'=>'Su 12:00-16:00'},
	{'text'=>'Tuesday, Wednesday, Thursday 9am-1pm','good'=>'Tu 09:00-13:00; We 09:00-13:00; Th 09:00-13:00'},
	{'text'=>'Wednesday-Friday, 10.30am-3pm','good'=>'We-Fr 10:30-15:00'},
	{'text'=>'Every Wednesday, 1pm-3pm','good'=>'We 13:00-15:00'},
	{'text'=>'9am-5pm, daily','good'=>'Mo-Su 09:00-17:00'},
	{'text'=>'Weekdays, 9am-2pm','good'=>'Mo-Fr 09:00-14:00'},
	{'text'=>'Sunday 10.30am-11.30pm; Wed 11.30am-3.30pm; Thur 2pm-4pm','good'=>'Su 10:30-23:30; We 11:30-15:30; Th 14:00-16:00'},
	{'text'=>'Thursdays &amp; Fridays, 11:00am-2:00pm','good'=>'Th 11:00-14:00; Fr 11:00-14:00'},
	{'text'=>'10am-4pm, Monday - Saturday','good'=>'Mo-Sa 10:00-16:00'},
	{'text'=>'Monday &amp; Tuesdays 9am-4pm, Wednesday &amp; Thursday 9am-4pm, 6.30pm-10pm, Friday 9am-11pm, Saturday 12pm-11pm, Sunday 12pm-8pm.','good'=>'Mo 09:00-16:00; Tu 09:00-16:00; We 09:00-16:00; Th 09:00-16:00; Fr 09:00-23:00; Sa 12:00-23:00; Su 12:00-20:00'},
	{'text'=>'Wednesday: Wednesdays 10.30am - 11.30am.Second Wednesday of the month 2.30pm - 3.30pm, Saturday: First Saturday of the month 10.30am - 12pm, Sunday: 11am - 12.30pm28 January 2023/25 Feb/25 March 2023 3pm-4pm','good'=>'We 10:30-11:30; We[2] 14:30-15:30; Sa[1] 10:30-12:00; Su 11:00-12:30'},
	{'text'=>'First Tuesday of the month: 1.30pm - 3.30pm, Fourth Tuesday of the month: 2pm - 5pm, Wednesday (term-time only): 11am - 12.30pm, Friday: 10.30am - 12pm, First Saturday of the month: 12.30pm - 2.30pm, First Sunday of the month: 10.45am - 12pm, Second, third and fourth Sunday of the month: 9.15am - 10.15am','good'=>'Tu[1] 13:30-15:30; Tu[4] 14:00-17:00; We 11:00-12:30; Fr 10:30-12:00; Sa[1] 12:30-14:30; Su[1] 10:45-12:00; Su[2,3,4] 09:15-10:15'},
	{'text'=>'Every Wednesday at Wednesday Cafe from 10.00-11.30, Every Saturday at Saturday Cafe from 10.00-11.00, Every Sunday at The Free Community Breakfast from 10.00-10.400.','good'=>'We 10:00-11:30; Sa 10:00-11:00; Su 10:00-10:40'},
	{'text'=>'Friday: The last Friday of each month from 2pm - 4pm','good'=>'Fr[-1] 14:00-16:00'},
	{'text'=>'Monday-Friday: 8am-noon and 1pm-5:30pm','good'=>'Mo-Fr 08:00-12:00,13:00-17:30'},
	{'text'=>'Mo-Fr 08:00-17:30','good'=>'Mo-Fr 08:00-17:30'},
	{'text'=>'Mo-Fr 08:00-12:00,13:00-17:30; Sa 08:00-12:00','good'=>'Mo-Fr 08:00-12:00,13:00-17:30; Sa 08:00-12:00'},
	{'text'=>'Every day 9am to 5pm','good'=>'Mo-Su 09:00-17:00'},
	{'text'=>'Mon/Wed/Thurs/Fri:  08:20 - 08:45','good'=>'Mo 08:20-08:45; We 08:20-08:45; Th 08:20-08:45; Fr 08:20-08:45'},
	{'text'=>'10-12 Thursdays','good'=>'Th 10:00-12:00'},
	{'text'=>' wednesday: 11:00 - 14:00, sunday: 10:30 - 12:00 ','good'=>'We 11:00-14:00; Su 10:30-12:00'},
	{'text'=>'Warm space/ refreshments activities daily 12noon - 10pm','good'=>'Mo-Su 12:00-22:00'},
	{'text'=>'7 days a week, 24 hours','good'=>'Mo-Su 00:00-24:00'},
	{'text'=>'Friday - 10am until 2pm','good'=>'Fr 10:00-14:00'}
);

for($i = 0; $i < @tests; $i++){
	$d = parseOpeningHours({'_text'=>$tests[$i]{'text'}});
	msg("<green>Test ".($i+1)."<none>:\n");
	msg("  Input: \"$tests[$i]{'text'}\"\n");
	$good = ($tests[$i]{'good'} ? ($d->{'opening'} eq $tests[$i]{'good'} ? '<green>':'<red>') : '<none>');
	msg("  Output: $good\"$d->{'opening'}\"<none>\n");
	msg("  Ideal:  $good\"$tests[$i]{'good'}\"<none>\n");
}