package MotionProxyQueueObject;
use strict;
#use diagnostics;
#use warnings;

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

#  $self->initialize();
  return $self;
}

sub done {
  my $self=shift;
  
  unlink($self->{name});
}

#sub initialize {
#  my $self=shift;  
#  my $dir=$self->{queue}->{camera}->{inpath};
#  $self->p();
#}

sub p {
  my $self=shift;
  print "queue = ", $self->{queue}, " .\n";
  print "name  = ", $self->{name}, " .\n";
  print "time  = ", scalar localtime($self->{time}), " .\n";
  printf "bytes = %d .\n",  $self->{bytes};
}
1;




__END__

