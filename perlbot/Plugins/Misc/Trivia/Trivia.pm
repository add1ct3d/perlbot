package Perlbot::Plugin::Trivia;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;
use Time::HiRes qw(time);
use DB_File;

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_msg(0);
  
  $self->{state} = 'idle';
  $self->{question} = -1;

  $self->{questions} = {};

  print "file: " . File::Spec->catfile($self->{directory}, 'trivia') . "\n";

  open(TRIVIA, File::Spec->catfile($self->{directory}, 'trivia'));
  my $i = 0;
  while(my $q = <TRIVIA>) {
    chomp $q;
    $self->{questions}{$i} = $q;
    $i++;
  }
  close(TRIVIA);

  $self->{players} = {};
  tie %{$self->{playersoverall}},  'DB_File', File::Spec->catfile($self->{directory}, 'playersoveralldb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->{askedtime} = 0;
  
  $self->{usersfastest} = {};
  tie %{$self->{usersfastestoverall}},  'DB_File', File::Spec->catfile($self->{directory}, 'usersfastetsoveralldb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  tie %{$self->{rank}}, 'DB_File', File::Spec->catfile($self->{directory}, 'rankdb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->{curquestion} = 1;
  $self->{numquestions} = 0;
  $self->{answered} = 0;

  $self->hook('trivia', \&starttrivia);
  $self->hook('stoptrivia', \&stoptrivia);
  $self->hook_regular_expression('.*', \&answer);

}

sub starttrivia {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  
  if($self->{state} ne 'idle') {
    $self->reply_error('A trivia game is already in progress!');
    return;
  }

  $self->{state} = 'playing';

  my ($numquestions) = $text =~ /(\d+)/;
  $numquestions ||= 15;

  $self->{numquestions} = $numquestions;
  $self->reply("Starting a new trivia game of $numquestions questions!");

  $self->{perlbot}{ircconn}->schedule(10, sub { $self->askquestion() });
}

sub stoptrivia {
  my $self = shift;

  $self->{state} = 'idle';
  $self->reply('Trivia stopped!');
  $self->endofgame();

}

sub answer {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $nick = $self->{lastnick};

  if($self->{state} ne 'asked' || $self->{answered}) {
    return;
  }

  my ($category, $question, $answer) = split(':::', $self->{questions}{$self->{question}});

  if(lc($text) eq lc($answer)) {
    $self->{answered} = 1;
    $self->{players}{$nick}++;
    $self->{playersoverall}{$nick}++;
    my $timediff = sprintf("%0.2f", time() - $self->{askedtime});
    if(!exists($self->{usersfastest}{$nick})) {
      $self->{usersfastest}{$nick} = $timediff;
      $self->{usersfastestoverall}{$nick} = $timediff;
    }

#    foreach my $tmpnick (keys(%{$self->{playersoverall}})) {
#
#    }

    my $rank = '-1';
    $self->reply("The answer was: $answer");
    $self->reply("Winner: $nick  Time: $timediff (This Round: Fastest: $self->{usersfastest}{$nick} Wins: $self->{players}{$nick}) Overall: Fastest: $self->{usersfastestoverall}{$nick} Wins: $self->{playersoverall}{$nick} Rank: $rank");
    if($timediff < $self->{usersfastest}{$nick}) {
      $self->{usersfastest}{$nick} = $timediff;
      $self->{usersfastestoverall}{$nick} = $timediff;
    }

    $self->{curquestion}++;
    $self->{perlbot}{ircconn}->schedule(10, sub { $self->askquestion() });

  }
}

sub askquestion {
  my $self = shift;

  if($self->{state} eq 'idle') {
    return;
  }
  
  if($self->{curquestion} <= $self->{numquestions}) {

    $self->{question} = rand(100000) % keys(%{$self->{questions}});
    $self->{state} = 'asked';
    
    my ($category, $question, $answer) = split(':::', $self->{questions}{$self->{question}});
    my $curquestion = $self->{curquestion};

    $self->{answered} = 0;
    $self->reply("${curquestion}. [${category}] $question");
    $self->{askedtime} = time();
    $self->{perlbot}{ircconn}->schedule(10, sub { $self->hint("$curquestion") });
    $self->{perlbot}{ircconn}->schedule(30, sub { $self->notanswered("$curquestion") });
  } else {
    $self->reply("Game over.");
    $self->endofgame();
    $self->{state} = 'idle';
    $self->{curquestion} = 1;
  }
}

sub hint {
  my $self = shift;
  my $question = shift;

  if($self->{state} ne 'asked' || $self->{curquestion} != $question) {
    return;
  }

  my ($category, $q, $a) = split(':::', $self->{questions}{$self->{question}});

  my $blackout;
  if(length($a) > 3) {
    $blackout = (length($a) / 2) + (rand(1000) % (length($a)/4)) - 1;
  } else {
    $blackout = length($a);
  }

  my $hint;
  if(int(rand(2)) == 1) {
    substr($a, 0, (length($a) - $blackout)) =~ tr[ A-Za-z0-9][ #];
  } else {
    substr($a, (length($a) - $blackout)) =~ tr[ A-Za-z0-9][ #];
  }

  $self->reply("Hint: $a");
}

sub notanswered {
  my $self = shift;
  my $question = shift;

  print "curquestion: $self->{curquestion} / passed: $question\n";

  if($self->{state} ne 'asked' || $self->{curquestion} != $question) {
    return;
  }

  my ($category, $questiontext, $answer) = split(':::', $self->{questions}{$self->{question}});

  $self->reply("The answer was: $answer");
  $self->{state} = 'playing';
  $self->{perlbot}{ircconn}->schedule(10, sub { $self->askquestion() });
  $self->{curquestion}++;

}

sub endofgame {
  my $self = shift;
  my $winner;
  my $winnerscore = -1;

  foreach my $nick (keys(%{$self->{players}})) {
    if($self->{players}{$nick} > $winnerscore) {
      $winner = $nick;
      $winnerscore = $self->{players}{$nick};
    }
    $self->{players}{$nick} = 0; # reset wins
  }

  if($winnerscore == -1) {
    return;
  }

  my $fastest = $self->{usersfastest}{$winner};

  $self->reply("Trivia Winner for this round is: $winner with $winnerscore wins and a fastest time of $fastest!");
}

1;






