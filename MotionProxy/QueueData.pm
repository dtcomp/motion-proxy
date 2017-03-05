package MotionProxy::QueueData;
use Time::HiRes;
use strict;
use Log::Lite qw(logrotate logmode logpath log);
use MotionProxy::QueueObject;
use MotionProxy::Constant;
use diagnostics;
use warnings;
use threads (
  'yield',
  'stack_size' => 128 * 4096,
  'exit'       => 'threads_only',
  'stringify'
);



#our %Instances;

sub new {
  my $class  = shift;
  my $camera = shift;

  my $self = bless {
    camera         => $camera,
    data           => [],
    skipped        => 0,
    total          => 0,
    minsize_events => 0,
    maxsize_events => 0,
    last           => undef
  }, $class;

  return $self;
}

sub count {
  my $self=shift;
  return scalar(@$self->{data});
}

sub sortc {
  my $self = shift;
  my $ar   = $self->{data};

  # Sort by ctime
  @$ar = sort { return $a->{time} <=> $b->{time}; } @$ar;
  return;
}

sub make_list {
  my $self = shift;
  my $dir  = shift;

  my $dh = DirHandle->new($dir);
  my @list;

#  print "Scanning $dir \n";
  while ( defined( $_ = $dh->read() ) ) {
    next unless (/\.jpg$/i);
    push @list, File::Spec->catfile( $dir, $_ );
  }
  return \@list;
}


sub you_sys {
  my $self=shift;
  my $status=system(@_);
  if ( $main::Debug > 10 ) {
        print 'ARGS: ', @_ , ' .\n';
        if ($status == -1) {
            print "failed to execute: $!\n";
        }
        elsif ($status & 127) {
            printf "child died with signal %d, %s coredump\n",
                ($status & 127),  ($status & 128) ? 'with' : 'without';
        }
        else {
            printf "child exited with value %d\n", $status >> 8;
        }
  }
  return $status;
}


sub byte_check_min {
  my $self      = shift;
  my $full_path = shift;
  my $bytes     = shift;
  my $minsize   = shift;
  my $times = 0;
  my @stat;

  threads->yield();
  while ( $self->you_sys('/bin/fuser', '-s', $full_path) == 0 ) {
    log( MotionProxy::Constant::LOGNAME, "Waiting for: $full_path, $times .\n" );
    usleep(1);
    ++$times;
  }

  if ( $times > 0 ) {
    @stat = ( stat $full_path );
    scalar(@stat) or die ("Stat failed for $full_path .\n");
    $bytes = $stat[7];
  }

  if ( $bytes < $minsize ) {
    log( MotionProxy::Constant::LOGNAME, "Bytes: $bytes < $minsize, $full_path .\n" );
    unlink $full_path  unless ($bytes == 0);  
    ++$self->{skipped};
    ++$self->{minsize_events};
    return undef;
  }
  return $bytes;
}

sub fill {
  my $self    = shift;
  my $camera  = MotionProxy::Camera::ResolveAliasRef( $self->{camera} );
  my $dir     = $camera->{inpath};
  my $minsize = $camera->{minsize};
  my $maxsize = $camera->{maxsize};
  my $cnt     = 0;
  my @stat;

  my $files = $self->make_list( $camera->{inpath} );

  for my $full_path ( @{$files} ) {
#    log( MotionProxy::Constant::LOGNAME, "File: $full_path. " );
    @stat = ( stat $full_path );
    scalar(@stat) or die ("Stat failed for $full_path .\n");
    my $bytes = $stat[7];
    my $ctime = $stat[10];

    if ( $bytes < $minsize ) {
      $bytes = $self->byte_check_min( $full_path, $bytes, $minsize );
    }
    next unless defined($bytes);

    if ( $bytes > $maxsize ) {
      log( MotionProxy::Constant::LOGNAME, "Bytes: $bytes > $maxsize, $full_path .\n" );
      unlink $full_path;
      ++$self->{skipped};
      ++$self->{maxsize_events};
      next;
    }
    my $obj = new MotionProxy::QueueObject( $self, $full_path, $ctime, $bytes );
    $self->enqueue($obj);
    ++$cnt;
  }
  $self->sortc();
  if ( $cnt > 0 ) {
    print "$camera->{name} Got $cnt files. \n";
  }
  return $cnt;
}

sub enqueue {
  my $self = shift;
  my $obj  = shift;
  if ( defined($obj) ) {
    push @{ $self->{data} }, $obj;
  }
  return;
}

sub dequeue {
  my $self = shift;
  if ( defined( $self->{last} ) ) {
    return $self->{last}->done();
  }
  return;
}

sub next {
  my $self = shift;
  my $ar   = $self->{data};
  my $n    = scalar @{$ar};

  if ( $n < 1 ) {
    $self->{last} = undef;
    return undef;
  }
  my $obj = shift @{$ar};
  $self->{last} = $obj;
  return $obj;
}

sub p {
  my $self = shift;
  print 'camera = ', $self->{camera}, ' .\n';
}

1;

__END__

