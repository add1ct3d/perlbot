package Perlbot::Plugin::Protection;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(deoppers);

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

#  $self->want_fork(0);

  $self->{deoppers} = {};

  $self->hook( eventtypes => 'mode', coderef => \&modechange );
}

sub modechange {
  my $self = shift;
  my $event = shift;
  my $modestring = $event->{args}[0];

  my $deopper = $event->nick();
  my $mintime = $self->config->get('mintimebetweendeops');

  if ($deopper eq $self->perlbot->curnick) { return; }

  if ($modestring =~ /-o/) {
    my $numdeops = length(($modestring =~ /-(o+)/g)[0]);

    if ($numdeops > 1 && $mintime > 0) {
      $self->perlbot->deop($event->{to}[0], $event->nick());
    } elsif ($self->{deoppers}{$deopper} &&
             (time() - $self->{deoppers}{$event->nick()}) < $mintime) {
      $self->perlbot->deop($event->{to}[0], $event->nick());
    }

    $self->{deoppers}{$event->nick()} = time();

    foreach my $deopper (keys(%{$self->{deoppers}})) {
      if (time() - $self->{deoppers}{$deopper} > $mintime) {
        delete $self->{deoppers}{$deopper};
      }
    }
  }
}

1;



