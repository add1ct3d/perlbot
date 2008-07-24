# Traceroute plugin
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Traceroute;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(traceroutebinary);

use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->{traceroutebinary} = '/usr/sbin/traceroute';

  $self->hook('traceroute', \&host);
  $self->hook('tr', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = Perlbot::Utils::exec_command($self->{traceroutebinary}, $text);

  $self->reply(@result);
}

