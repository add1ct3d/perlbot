package Babelfish::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

use WWW::Babelfish;

sub init {
  my $self = shift;

  $self->hook('translate', \&translate);
  $self->hook('babelfish', \&translate);
}

sub translate {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($source, $dest, $string) = split(' ', $text, 3);

  my $obj = new WWW::Babelfish( 'agent' => 'Perlbot/$VERSION');
  
  if(!$obj) {
    $self->reply_error('Couldn\'t connect to babelfish.altavista.com!');
    return;
  }

  my @languages = $obj->languages();

  if($source && $dest && $string) {

    $source =~ s/(.)(.*)/\u$1\L$2\E/;
    $dest =~ s/(.)(.*)/\u$1\L$2\E/;

    $result = $obj->translate( 'source' => $source,
                               'destination' => $dest,
                               'text' => $string);

    if($result) {
      $self->reply($result);
    } else {
      $self->reply('Unable to translate!');
    }
  } else {
    $self->reply_error('You must specify: <source language> <dest language> <string to translate>');
    $self->reply_error('Available languages: ' . join(' ', @languages));
    $self->reply_error('Note: Not all languages can be translated to all other languages.');
  }
}
