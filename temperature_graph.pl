#!/usr/bin/perl
# I don't use Perl almost ever anymore, so apologies if parts read a little Haskell-y.
use strict;
use Time::Piece;
use DateTime; #because Time::Piece doesn't really have setters :-/

my @temperature_strings_c = `grep -h ata-ST3000DM001-9YN166_W1F0MYCM /var/log/messages* | grep hddtemp | awk '{print \$8}'`;
my @date_strings = `grep -h ata-ST3000DM001-9YN166_W1F0MYCM /var/log/messages* | grep hddtemp | cut -c 1-16`;
map { chop; chop; } @date_strings; #"A little of the ol' 'chop chop'!" ~TF2 Sniper

my @temps = map { $_ * 1.8 + 32 } @temperature_strings_c;

my $current = localtime;
my @dates = map { Time::Piece->strptime($_, '%b %d %T') } @date_strings;
my @datetimes = map { DateTime->new(year => $current->year, month => $_->mon, day => $_->mday, hour => $_->hour, minute => $_->min, second => $_->sec) } @dates;

if ($dates[-1]->fullmonth eq "January"){
	foreach my $date (@datetimes){
		$date->set (year => $current->year-1) if $date->month_name eq "December"
	}
}

my $webpage = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <title>Recent Temperatures</title>
  <script type="text/javascript" src="http://www.google.com/jsapi"></script>
  <script type="text/javascript">
google.load('visualization', '1', {packages: ['annotatedtimeline']});
function drawVisualization() {
  var data = new google.visualization.DataTable();
  data.addColumn('datetime', 'Date');
  data.addColumn('number', 'Temperature (degF)');
  data.addRows([
EOF

for( my $i=0; $i < @datetimes; $i++){
	$webpage = $webpage . jsify_data($datetimes[$i], $temps[$i]);
}
chomp $webpage;
chop $webpage;

sub jsify_data {
	my ($date, $temp) = @_;
	my $year = $date->year();
	my $month = $date->month()-1; #Whatever, javascript. Whatever.
	my $day = $date->day();
	my $hours = $date->hour();
	my $minutes = $date->minute();
	my $seconds = $date->second();

	"    [new Date($year, $month, $day, $hours, $minutes, $seconds), $temp],\n";
}

$webpage = $webpage . <<EOF

  ]);

  var annotatedtimeline = new google.visualization.AnnotatedTimeLine(
      document.getElementById('visualization'));
  annotatedtimeline.draw(data, {'displayAnnotations': true, 'scaleType': 'maximized'});
}
    
    google.setOnLoadCallback(drawVisualization);
  </script>
</head>
<body style="font-family: Arial;border: 0 none;">
<div id="visualization" style="width: 100%; height: 400px;"></div>
</body>
</html>
EOF
;

print "$webpage\n";
