package Perlbot::Config;


use strict;
use Carp;
use XML::Simple;
use Perlbot::Utils;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(filename readonly config);

sub new {
  my $self = shift;
  my ($filename, $readonly) = (@_);

  $self = fields::new($self) if !ref $self;

  $self->filename = $filename;
  $self->readonly = $readonly ? 1 : undef;
  $self->config = {};

  # if we didn't get a filename, just send back a config object
  # otherwise
  #   try to load the config
  #   if we can't, then return undef

  if (!$filename) {
    return $self;
  } else {
    $self->load or $self = undef;
    return $self;
  }

}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  debug("Got call for field: $field", 15);

  if(!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  $self->{$field};
}

sub load {
  my ($self) = @_;

  return $self->config = read_generic_config($self->filename);
}


sub save {
  my ($self) = @_;

  debug("attempting to save " . $self->filename . " ...");
  if ($self->readonly) {
    debug("  Config object is read-only; aborting");
    return 0;
  }
  my $ret = write_generic_config($self->filename, $self->config);
  debug($ret ? "  success" : "  failure");
  return $ret;
}


# fetch data from the config
# params:
#   A list of hash keys and array indices that leads down the config tree
#   to the desired point.
# returns:
#   For a "leaf" scalar value, the scalar itself.  Otherwise, a reference
#   to the requested mid-level hash or array.  The method call may be used
#   as an lvalue to set the value in the config object!
# notes:
#   A useful idiom is to use the => operator between parameters.  Thus you
#   may omit quotes around barewords (except for the rightmost one), and
#   it's also a nice visual representation of what you're asking for.
#   ALSO: if you have a nested object in your config with only one
#   instance (like the "bot" object in the base config) then you may omit
#   the 0 in between hash key parameters. (see last few examples below)
# examples:
#   _value('channel')                  # hashref of channels, keyed on name
#   _value(channel => '#perlbot')      # hashref of single channel's fields
#   _value(channel => '#perlbot' => 'op')                 # arrayref of ops
#   foreach (@{_value(channel=>'#perlbot'=>'op')}) {...}  # same
#   _value(bot => 'nick')              # omitting the 0
#   _value(bot => 0 => 'nick')         # this works but the 0 isn't needed
#   _value(bot => 'nick') = 'NewNick'  # assignment

# TODO: make sure that when a non-existent entity is queried, no
#       hash or array entries spring into existence!

sub _value : lvalue {
  my ($self, @keys) = @_;
  my ($current, $key, $type, $ref);

  debug(join('=>', @keys), 9);

  # $current is a "pointer", iterated down the tree
  $current = $self->config;
  # $ref is a reference to whatever $current is storing
  $ref = \$self->config;

  # loop over the list of keys we got
  while (defined ($key = shift @keys)) {
    # grab what kind of reference the current thing is
    $type = ref($current);
    if ($type eq 'ARRAY') {
      # check to see if $key is a non-integer (ints required for array indexing)
      if ($key =~ /\D/) {
        # special case for singleton objects, so the 0 index can be
        # omitted as the second parameter, e.g. this lets you write
        # _value('bot','nick') instead of _value('bot',0,'nick)
        if (@$current == 1) {
          unshift(@keys, $key);
          $key = 0;
        } else {
          # otherwise, complain and return undef
          carp "non-integer key specified for array lookup ($key)";
          return undef;
        }
      }
      # "move pointer" down to next level
      if (exists $current->[$key]) {
        $ref = \$current->[$key];
        $current = $$ref;
      } else {
        # non-existent branch; return undef
        $current = $ref = undef;
        last;        
      }
    } elsif ($type eq 'HASH') {
      # no validity checks here; a hash key could be anything.
      # "move pointer" down to next level
      if (exists $current->{$key}) {
        $ref = \$current->{$key};
        $current = $$ref;
      } else {
        # non-existent branch; return undef
        $current = $ref = undef;
        last;
      }
    ### Proxy stuff for the future
    #} elsif (UNIVERSAL::isa($ref, 'Perlbot::Config::Proxy')) {
    #  # we've hit a proxy config object.  pass the rest of the keys to
    #  # it and return whatever it spits back.
    #  $ref = $ref->get(@keys);
    #  last;
    } else {
      # if we get here, we've reached a "leaf" in the tree but there are
      # still more keys to deal with... that's bad.  complain and stop
      # iterating.  we will return undef.
      debug("extra config keys specified: " . join('=>', $key, @keys));
      $current = $ref = undef;
      last;
    }
  }

  # Dereferencing $ref (and omitting 'return'!) is how we get the lvalue
  # stuff to work, so don't touch this unless you know what you're doing!
  $ref or return undef;
  $$ref;
}

sub exists {
  my $self = shift;

  return defined $self->_value(@_);
}

sub get {
  my $self = shift;

  my $ret = $self->_value(@_);
  if (ref $ret) {
    # if an array itself was specified, return element 0
    if (ref $ret eq 'ARRAY') {
      debug("assuming array index 0", 9);
      return $self->_value(@_, 0);
    } else {
      debug("request for non-leaf node: ". join('=>', @_));
    }
  }
  return $ret;
}

sub set {
  my $self = shift;
  my $value = pop;

  my $ret = $self->_value(@_);
  if (ref $ret) {
    debug("request for non-leaf node: ". join('=>', @_));
  }
  if (!$self->exists(@_)) {
    my @parent_keys = @_[0..@_-2];
    my $key = @_[@_-1];
    if (ref $self->_value(@parent_keys) eq 'HASH') {
      $self->_value(@parent_keys)->{$key} = undef;
    }
  }
  $self->_value(@_) = $value;
}

# only use the array_ methods on arrays of regular scalars
# (i.e. no sub-objects)

sub array_get {
  my $self = shift;

  return $self->exists(@_) ? @{$self->_value(@_)} : ();
}

sub array_initialize {
  my $self = shift;
  my $key = pop;

  my $arrayref = $self->_value(@_);
  $arrayref->{$key} = [];
}

sub array_push {
  my $self = shift;
  my $value = pop;

  $self->exists(@_) or $self->array_initialize(@_);
  my $arrayref = $self->_value(@_);
  push @$arrayref, $value;
}

sub array_delete {
  my $self = shift;
  my $value = pop;

  $self->exists(@_) or return undef;
  @{$self->_value(@_)} = grep {$_ ne $value} $self->array_get(@_);
}


sub hash_keys {
  my $self = shift;

  return $self->exists(@_) ? keys %{$self->_value(@_)} : ();
}

sub hash_initialize {
  my $self = shift;
  my $key = pop;

  my $hashref = $self->_value(@_);
  $hashref->{$key} = {};
}

sub hash_delete {
  my $self = shift;
  my $key = pop;

  $self->exists(@_) or return;
  my $hashref = $self->_value(@_);
  delete $hashref->{$key};
}


# AUTOLOAD has problems otherwise.  :)
sub DESTROY {
}


1;
