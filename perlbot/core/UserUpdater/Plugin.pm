package UserUpdater::Plugin;

use PerlbotUtils;
use Perlbot;
use User;
use Plugin;

@ISA = qw(Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->{perlbot}->add_handler('public', sub { $self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('caction', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('join', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('part', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('mode', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('topic', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('nick', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('quit', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('kick', sub {$self->update(@_) }, $self->{name});
  $self->{perlbot}->add_handler('namreply', sub {$self->update(@_) }, $self->{name});

}

# ============================================================
# event handlers
# ============================================================

sub update {
  my $self = shift;
  my $event = shift; 
  my $userhost = $event->nick.'!'.$event->userhost;
  my $type = $event->type;
  my $nick = $event->nick;
  my $channel = normalize_channel($event->{to}[0]);
  my $text = $event->{args}[0];
  my $user = $self->{perlbot}->get_user($userhost);

  if($type eq 'join') {
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->add_member($nick);
    }
  }

  if($type eq 'part') {
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->remove_member($nick);
    }
  }

  if($type eq 'nick') {
    foreach my $chan (values(%{$self->{perlbot}{channels}})) {
      if($chan->is_member($nick)) {
        $chan->remove_member($nick);
        $chan->add_member($event->{args}[0]);
      }
    }
  }

  if($type eq 'kick') {
    my $chan = normalize_channel($event->{args}[0]);
    if($self->{perlbot}{channels}{$chan}) {
      $self->{perlbot}{channels}{$chan}->remove_member($nick);
    }
  }

  if($type eq 'namreply') {
    my $chan = normalize_channel($event->{args}[2]);
    my $nickstring = $event->{args}[3];
    $nickstring =~ s/\@//g;
    my @nicks = split(' ', $nickstring);
    if($self->{perlbot}{channels}{$chan}) {
      foreach my $nick (@nicks) {
        $self->{perlbot}{channels}{$chan}->add_member($nick);
      }
    }
  }

  if($user) {
    $user->{curnick} = $nick;
    $user->{lastseen} = time();

    if(!$user->{notified} && $user->notes >= 1) {
      my $numnotes = $user->notes;
      my $noteword = ($numnotes == 1) ? 'note' : 'notes';
      $self->{perlbot}->msg($nick, "$numnotes $noteword stored for you.");
      $user->{notified} = 1;
    }
  }
  return $user;

}

1;
