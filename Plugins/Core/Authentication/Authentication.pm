package Perlbot::Plugin::Authentication;

use strict;

use base qw(Perlbot::Plugin);

use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

#  $self->want_public(0);
#  $self->want_fork(0);

  $self->hook('auth', \&auth);
  $self->hook('password', \&password);
  $self->hook('hostmasks', \&hostmasks);
  $self->hook('addhostmask', \&addhostmask);
  $self->hook('removehostmask', \&removehostmask);
}

sub auth {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;
  my $userhost = $event->from();
  my ($username, $password) = split(' ', $text, 2);

  if (!$username || !$password || $password eq "''") {
    $self->reply_error('Please refer to the help for the Authentication plugin!');
    return;
  }

  if (my $check_user = $self->perlbot->get_user($username)) {
    if($check_user->authenticate($password)) {
      $check_user->add_temp_hostmask($userhost);
      $check_user->curnick($event->nick);
      $self->reply("User $username authenticated!");
    } else {
      $self->reply_error('Bad password!');
    }
  } else {
    $self->reply_error("No such user: $username");
    return;
  }
}

sub password {
  my $self = shift;
  my $user = shift;
  my $newpassword = shift;

  if (!$newpassword) {
    $self->reply_error('Must specify a new password!');
    return;
  }

  if (!$user) {
    $self->reply_error('Not a known user, try auth first!');
    return;
  }

  $user->password($newpassword);
  $user->config->save;

  $self->reply('Password successfully changed');
}

sub hostmasks {
  my $self = shift;
  my $user = shift;

  if (!$user) {
    $self->reply_error('Not a known user, try auth first!');
    return;
  }

  if(!$user->hostmasks) {
    $self->reply_error('No hostmasks specified!');
    return;
  } else {
    foreach my $hostmask ($user->hostmasks) {
      $self->reply($hostmask);
    }
  }
}

sub addhostmask {
  my $self = shift;
  my $user = shift;
  my $hostmask = shift;

  if (!$hostmask) {
    $self->reply_error('You must specify a hostmask to add!');
    return;
  }

  if (!$user) {
    $self->reply_error('You are not a known user!');
    return;
  }

  if (!validate_hostmask($hostmask)) {
    $self->reply_error("Invalid hostmask: $hostmask");
  } else {
    $user->add_hostmask($hostmask);
    $user->config->save;
    $self->reply("Permanently added $hostmask to your list of hostmasks.");
  }

}

sub removehostmask {
  my $self = shift;
  my $user = shift;
  my $hostmask = shift;

  if(!$hostmask) {
    $self->reply('You must specify a hostmask to remove!');
    return;
  }

  if(!$user) {
    $self->reply('You are not a known user!');
    return;
  }

  my $old_num = $user->hostmasks;
  $user->remove_hostmask($hostmask);
  if ($user->hostmasks == $old_num) {
    $self->reply("$hostmask not in your list of hostmasks!");
  } else {
    $self->perlbot->config->save;
    $self->reply("Permanently removed $hostmask from your list of hostmasks.");
  }

}


1;
