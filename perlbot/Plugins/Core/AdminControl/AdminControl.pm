package Perlbot::Plugin::AdminControl;

use Perlbot;
use Perlbot::Utils;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook_admin('reload', \&reload);
}

sub nick {
  my $self = shift;
  my $user = shift;

  if($self->perlbot->reload_config()) {
    $self->reply('Reloaded config file!');
  } else {
    $self->reply_error('Could not reload config file!');
  }
}

1;
