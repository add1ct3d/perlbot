# Andrew Burke <burke@bitflood.org>
#
# This plugin munges the in-memory config and writes it back out,
# careful

package Perlbot::Plugin::UserAdmin;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Perlbot::Utils;
use Perlbot::User;

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_reply_via_msg(1);
  $self->want_public(0);

  $self->hook_admin('useradmin', \&useradmin);

}

sub useradmin {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($command, $username, $arguments) = split(' ', $text, 3);

  if (!$command) {
    $self->reply('You must specify a command!');
    return;
  }

  if (!$username) {
    $self->reply('You must specify a username!');
    return;
  }

  if ($command eq 'add') {
    $self->{perlbot}->config->value(user => $username) = {};
    $self->{perlbot}{users}{$username} = new Perlbot::User($username);
    $self->{perlbot}->config->save;
    $self->reply("Added user: $username");

  } elsif ($command eq 'remove') {
    if (!$self->{perlbot}->config->value(user => $username)) {
      $self->reply("$username is not a known user!");
      return;
    }
    # hash lookup must be performed "outside" of ->value call for delete to work
    delete $self->{perlbot}->config->value('user')->{$username};
    $self->{perlbot}->config->save;
    $self->reply("Removed user: $username");

  } elsif ($command eq 'hostmasks') {
    if (!$self->{perlbot}->config->value(user => $username)) {
      $self->reply("$username is not a known user!");
      return;
    }
    foreach my $hostmask (@{$self->{perlbot}->config->value(user => $username => 'hostmask')}) {
      $self->reply($hostmask);
    }

  } elsif ($command eq 'addhostmask') {
    my $hostmask = $arguments;
    if (!$hostmask) {
      $self->reply('You must specify a hostmask to add!');
      return;
    }
    if (!$self->{perlbot}->config->value(user => $username)) {
      $self->reply("$username is not a known user!");
      return;
    }
    if (!validate_hostmask($hostmask)) {
      $self->reply("Invalid hostmask: $hostmask");
    } else {
      push(@{$self->{perlbot}->config->value(user => $username => 'hostmask')},
           $hostmask);
      $self->{perlbot}->config->save;
      $self->{perlbot}{users}{$username}->hostmasks($hostmask);
      $self->reply("Permanently added $hostmask to ${username}'s list of hostmasks.");
    }

  } elsif ($command eq 'delhostmask') {
    my $hostmask = $arguments;
    if (!$hostmask) {
      $self->reply('You must specify a hostmask to delete!');
      return;
    }
    if (!$self->{perlbot}->config->value(user => $username)) {
      $self->reply("$username is not a known user!");
      return;
    }
    my $whichhost = 0;
    foreach my $confighostmask (@{$self->{perlbot}->config->value(user => $username => 'hostmask')}) {
      if ($confighostmask eq $hostmask) {
        last;
      }
      $whichhost++;
    }
    if ($whichhost >= @{$self->{perlbot}->config->value(user => $username => 'hostmask')}) {
      $self->reply("$hostmask is not in ${username}'s list of hostmasks!");
      return;
    }
    splice(@{$self->{perlbot}->config->value(user => $username => 'hostmask')},
           $whichhost, 1);
    $self->{perlbot}->config->save;
    $self->reply("Permanently removed $hostmask from ${username}'s list of hostmasks.");

  } elsif ($command eq 'password') {
    my $password = $arguments;
    if (!$password) {
      $self->reply('You must specify a new password!');
      return;
    }
    if (!$self->{perlbot}->config->value(user => $username)) {
      $self->reply("No such user: $username");
      return;
    }
    my $newpass = crypt($password, join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64]);
    $self->{perlbot}->config->value(user => $username => 'password') = $newpass;
    $self->{perlbot}{users}{$username}{password} = $newpass;
    $self->{perlbot}->config->save;
    $self->reply("Password saved for user: $username");

  } elsif($command eq 'addop') {
    my $channel = Perlbot::Utils::normalize_channel($arguments);
    if(!$channel || !$username) {
      $self->reply_error('You must specify both a channel and a username!');
      return;
    }
    if (!$self->{perlbot}->config->value(channel => $channel)) {
      $self->reply_error("No such channel: $channel");
      return;
    }
    if (!$self->{perlbot}->config->value(user => $username)) {
      $self->reply_error("No such user: $username");
      return;
    }
    if (grep { $_ eq $username }
        @{$self->{perlbot}->config->value(channel => $channel => 'op')}) {
      $self->reply_error("$username is already an op for $channel!");
      return;
    }
    push(@{$self->{perlbot}->config->value(channel => $channel => 'op')},
         $username);
    $self->{perlbot}{channels}{$channel}{ops}{$username} = 1;
    $self->{perlbot}->config->save;
    $self->reply("Added $username to the list of ops for $channel");

  } else {
    $self->reply_error("Unknown command: $command");
    return;

  }

  # successful command
}


1;
