# Prints contents of internal variables.  Limited to owners.
#
# Author: Mike Edwards	Date: 10/22/2001
#
# This free software is licensed under the terms of the GNU public license.
# Copyleft 2001 Mike Edwards
#
# Ported to the new plugin interface by burke@bitflood.org

package Internals::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use Data::Dumper;

sub init {
  my $self = shift;

  $self->want_reply_via_msg(1);
  $self->want_fork(0);

  $self->hook_admin('internal', \&internal);
}

sub internal {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my ($var, $replymethod) = split(' ', $text);

  my @data;

  @data = split '\n', Dumper (eval sprintf "%s", $var);
  if($replymethod eq "stdout") {
    # send to console
    print STDERR "internals: $var\n";
    print join "\n", @data;
    print "\ninternals: end of $var\n";
  } else {
    # send to privmsg
    $self->reply("internals: $var");
    foreach (@data) {
      $self->reply($_);
    }
    $self->reply("internals: end of $var");
  }
}

1;
