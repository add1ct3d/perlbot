#!/usr/bin/perl

# enter your perlbot logs directory here
my $directory = 'logs/';

use strict;
use CGI qw/-compile :standard :html3 :netscape/;

my $arg = shift;

print header;

print start_html(-bgcolor=>'white',-text=>'black',-title=>'IRC logs',
		 -style=>'A:link {text-decoration: none}');

opendir(DIRLIST, $directory);
my @diritems = readdir(DIRLIST); #for readability
closedir(DIRLIST);

if(!$arg) {
  print img({-src=>'logsearch.jpg'}), br;
  print "    <H2>Logs for channels:</H2>\n";
  print "    <P>\n";
  print "    <HR>\n";
  print "    <P>\n";

  print "    <UL>\n";
  foreach my $diritem (@diritems) {
    if (-d "$directory$diritem") {
      if (!($diritem =~ /^(\.\.?|msg)$/)) {
	print "    <LI><B><A HREF=\"index.pl?$diritem\">$diritem</A></B>\n";
      }
    }
  }
  print "    </UL>\n";

} else {

  my $chan = $arg;

  if(!opendir(LOGLIST, "$directory$chan")) {
    print "No logs for channel: $chan\n";
    exit 1;
  }

  my @tmpfiles =  readdir(LOGLIST);
  my @logfiles = sort(@tmpfiles);
  close LOGLIST;

  print "    <UL>\n";
  foreach my $logfile (@logfiles) {
    if (!($logfile =~ /^\.\.?$/)) {
      print "      <LI><A HREF=\"plog.pl?$chan/$logfile\">$logfile</A>\n";
    }
  }
  print "    </UL>\n";
}

print hr, br;

if ($arg) {
  print '<A HREF="">Return to the list of channels</A>', br;
}

print '<A HREF="search/index.pl">Search the logs</A>', end_html;



