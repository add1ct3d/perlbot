# Andrew Burke <burke@bitflood.org>
#
# Man, this is way bigger than I thought it would be
#
# TODO: make it use channel keys for password protection of the logs... ?
#       make this thing die cleanly

package Perlbot::Plugin::LogServer;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Headers;
use File::Spec;

sub init {
  my $self = shift;

  $self->want_msg(0);
  $self->want_public(0);

  $self->{logdir} = $self->{perlbot}->config('bot' => 'logdir');

  $self->hook_event('endofmotd', sub { $self->logserver });
  $self->hook_event('nomotd', sub { $self->logserver });

}

sub logserver {
  my $self = shift;
  my $logdir = $self->{logdir};
  my $server = HTTP::Daemon->new(LocalPort => 9000) || die;

  my $search = 0;

  while (my $connection = $server->accept()) {
    while (my $request = $connection->get_request()) {
      if ($request->method() eq 'GET') {
        my $response = '<html><head><title>Perlbot Logs</title></head><body><center><h1>Perlbot Logs</h1></center><hr>';
        my ($garbage, $chan, $year, $month, $day) = split('/', $request->url->path());

        if($year eq 'search') {
          $year = undef;
          $search = 1;
        }          

        if(!$chan && !$search) {
          if(opendir(DIR, $logdir)) {
            my @channels = readdir(DIR);
            closedir(DIR);

            $response .= '<ul>';
            foreach my $channel (@channels) {
              if (-d File::Spec->catfile($logdir, $channel)) {
                if ($channel !~ /^(\.\.?|msg)$/) {
                  $response .= "<li><b><a href=\"/${channel}\">$channel</a></b>";
                }
              }
            }
            $response .= '</ul>';
          } else {
            $response .= 'Could not open the bot\'s logdir!';
          }
        }
        if($chan && !$year && !$search) {
          if(!opendir(LOGLIST, File::Spec->catfile($logdir, $chan))) {
            $response .= "No logs for channel: $chan";
          } else {
            $response .= "<a href=\"/${chan}/search\">[search]</a><p>";
            my @tmpfiles =  readdir(LOGLIST);
            my @logfiles = sort(@tmpfiles);
            close LOGLIST;

            my @years;

            foreach my $logfile (@logfiles) {
              if (!($logfile =~ /^\.\.?$/)) {
                my ($tmpyear) = $logfile =~ /^(\d+)\./;

                if(!grep { /$tmpyear/ } @years) { push(@years, $tmpyear); }
              }
            }

            $response .= "<p><h2>Logs for $chan in:</h2>";
            $response .= '<p><hr><p><ul>';
            foreach my $year (@years) {
              $response .= "<li><b><a href=\"/${chan}/${year}\">$year</a></b>";
            }
            $response .= '</ul>';
          }
        }
        if($chan && $year && !$month && !$search) {
          $response .= "<a href=\"/${chan}/search\">[search]</a> <a href=\"/${chan}\">[top]</a><p>";

          use HTML::CalendarMonth;

          if(!opendir(LOGLIST, File::Spec->catfile($logdir, $chan))) {
            $response .= "No logs for channel: $chan";
          } else {
            my @tmpfiles =  readdir(LOGLIST);
            my @logfiles = sort(@tmpfiles);
            close LOGLIST;

            $response .= "<center><h1>Logs for channel: $chan</h1></center>";
            $response .= '<p><hr>';
            
            $response .= "<p><center><h1>$year</h1></center>\n";
            $response .= "<table width=\"100%\" border=\"0\">\n  <tr valign=\"center\" align=\"center\">\n";
            foreach my $month ((1..12)) {
              $response .= "    <td width=\"25%\" valign=\"center\" align=\"center\">\n";
              $month = sprintf("%02d", $month);
              my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
              foreach my $day ((1..31)) {
                my $paddedday = sprintf("%02d", $day);
                my $filename = "$year.$month.$paddedday"; 
                if(grep { /\Q$filename\E/ } @logfiles) {
                  $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/${chan}/${year}/${month}/${paddedday}"));
                }
              }
              $response .= $cal->as_HTML();
              $response .= "</td>\n";
              if($month % 4 == 0) { $response .="  </tr>\n  <tr>\n"; }
            }
            $response .= "</table>\n";
          }
        }

        if($chan && $year && $month && !$day && !$search) {
          $response .= "<a href=\"/${chan}/search\">[search]</a> <a href=\"/${chan}\">[top]</a><p>";
          use HTML::CalendarMonth;

          if(!opendir(LOGLIST, File::Spec->catfile($logdir, $chan))) {
            $response .= "No logs for channel: $chan";
          } else {
            my @tmpfiles =  readdir(LOGLIST);
            my @logfiles = sort(@tmpfiles);
            close LOGLIST;

            $response .= "<center><h1>Logs for channel: $chan</h1></center>";
            $response .= '<p><hr>';

            $response .= "<p><center><h1>$year</h1></center>\n";
            $month = sprintf("%02d", $month);
            my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
            foreach my $day ((1..31)) {
              my $paddedday = sprintf("%02d", $day);
              my $filename = "$year.$month.$paddedday";
              if(grep { /\Q$filename\E/ } @logfiles) {
                $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/${chan}/${year}/${month}/${paddedday}"));
              }
            }
            $response .= $cal->as_HTML();
          }
        }

        if($chan && $year && $month && $day && !$search) {
          $response .= "<a href=\"/${chan}/search\">[search]</a> <a href=\"/${chan}\">[top]</a><p>";
          my $filename = File::Spec->catfile($logdir, $chan, "$year.$month.$day");

          if(open(FILE, $filename)) {
            my @lines = <FILE>;
            close(FILE);

            foreach (@lines) {
              s/</\&lt\;/g;
              s/>/\&gt\;/g;
              s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
              s|^(\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
              s/^(\d+:\d+:\d+\s)(.*? joined \#.*?$)/$1<font color=\"blue\">$2<\/font>/;
              s/^(\d+:\d+:\d+\s)(.*? left \#.*?$)/$1<font color=\"blue\">$2<\/font>/;
              s/^(\d+:\d+:\d+\s)(\[.*?\])/$1<font color\=\"red\">$2<\/font>/;
              s/(\d+\:\d+:\d+)/<a name=\"$1\">$1<\/A>/;
              $response .= "<tt>$_</tt><br>";
            }
          }
        }                               

        if($search) {
          if($request->uri() !~ /\?/) {
            $response .= "<h2>Search logs for channel: $chan</h2><p>";
            $response .= "<form method=\"get\" action=\"/${chan}/search\">";
            $response .= "Enter words to search for: <input type=\"text\" name=\"words\"  />";
            $response .= "<input type=\"submit\" name=\".submit\" />";
            $response .= "</form>";
          } else {
            $response .= "<a href=\"/${chan}/search\">[search]</a> <a href=\"/${chan}\">[top]</a><p>";
            my ($tmpwords) = $request->uri() =~ /words\=(.*?)(?:\&|$)/;
            my @words = split(/\+/, $tmpwords);

            if(opendir(DIR, File::Spec->catfile($logdir, $chan))) {
              @tmp = readdir(DIR);
              @files = sort(@tmp);
              
              foreach $file (@files) {
                open(FILE, File::Spec->catfile($logdir, $chan, $file));
                @lines = <FILE>;
                close FILE;
                
                foreach $word (@words) {
                  @lines = grep(/\Q$word\E/i, @lines);  
                }
                
                foreach (@lines) {
                  s/</&lt;/g;
                  s/>/&gt;/g;
                }
                
                if (@lines) {
                  ($year, $month, $day) = split(/\./, $file);
                  $response .= "<b><a href=\"/${chan}/${year}/${month}/${day}\">$file</a></b>";
                  $response .= '<pre>';
                  foreach my $line (@lines) {
                    $line =~ s/(\d+:\d+:\d+)/<a href=\"\/${chan}\/${year}\/${month}\/${day}#$1\">$1<\/a>/;
                    $response .= $line;
                  }
                  $response .= '</pre>';
                }
              }
        
              closedir(DIR);
            }
          }
        }

#        if($chan) {
#          $response .= "<p><a href=\"/${chan}/search\">Search</a>";
#        }

        $response .= '</body></html>';
        $connection->send_response(HTTP::Response->new(HTTP::Response::RC_OK,
                                                       'yay!',
                                                       HTTP::Headers->new(Content_Type => 'text/html;'),
                                                       $response));
        $search = 0;
      }
    }
    $connection->close;
    undef($connection);
  }
}

1;

