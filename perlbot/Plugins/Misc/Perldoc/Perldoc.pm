# Perldoc
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Perldoc;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('perldoc', \&perldoc);
}

sub perldoc {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($max) = ($text =~ /(\d+)\s*$/);
  $text =~ s/\d+\s*$//;

  $max ||= 10;

  my @result = Perlbot::Utils::exec_command('perldoc', $text);

  my $linenum = 0;
  foreach my $line (@result) {
    if($linenum <= $max) {
      $self->reply($line);
    } else {
      $self->reply('[[ ' . (@result - $linenum) . ' lines not displayed ]]');
      last;
    }
    $linenum++;
  }
}

