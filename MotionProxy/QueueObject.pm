package MotionProxy::QueueObject;
use strict;
use Log::Lite qw(logrotate logmode logpath log);
use diagnostics;
use warnings;


sub new {
  my $class=shift;
  my $queue=shift;
  my $name=shift;  # filename
  my $time=shift;
  my $bytes=shift;

  my $self = bless {
    queue  => $queue,
    name   => $name,
    'time' => $time,
    bytes  => $bytes,
  }, $class;

  return $self;
}

sub done {
  my $self=shift;
  unlink($self->{name});
}

sub name {
  my $self=shift;
  return $self->{name};
}

sub p {
  my $self=shift;
  print "queue = ", $self->{queue}, " .\n";
  print "name  = ", $self->{name}, " .\n";
  print "time  = ", scalar localtime($self->{time}), " .\n";
  printf "bytes = %d .\n",  $self->{bytes};
}

sub p1 {
  my $self=shift;
  print $self->{time}, 
  " = ", $self->{name};
  printf "( %d )\n",  $self->{bytes};
}

1;




__END__

