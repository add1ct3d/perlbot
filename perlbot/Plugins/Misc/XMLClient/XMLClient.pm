package Perlbot::Plugin::XMLClient;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;
use RPC::XML::Client;
use XML::Simple;

sub init {
  my $self = shift;

  my $cli = RPC::XML::Client->new('http://' .
                                $self->config->value(master => 'host') .
                                ':' .
                                $self->config->value(master => 'port'));

  my $users = $cli->send_request(RPC::XML::request->new('perlbot.User'));

  print $users->value->value() . "\n";

  $self->{perlbot}->config->value('user') = XMLin($users->value->value());

}

1;
