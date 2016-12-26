package MotionProxy::QueueData;
use strict;
use Log::Lite qw(logrotate logmode logpath log);
use MotionProxy::QueueObject;
use MotionProxy::Constant;
use diagnostics;
use warnings;

#our %Instances;

sub new {
  my $class=shift;
  my $camera=shift;
  
  my $self = bless {
    camera  => $camera,
    data   => [],
    skipped => 0,
    total  => 0,
    minsize_events => 0,
    maxsize_events => 0,
    last  => undef
  }, $class;

  return $self;
}


sub sort {
    my $self = shift;
    my $ar   = $self->{data};
    # Sort by ctime
    @$ar = sort { return $a->{time} <=> $b->{time}; } @$ar;
}

sub fill {
    my $self    = shift;
    my $camera  = MotionProxy::Camera::ResolveAliasRef($self->{camera});
    my $dir     = $camera->{inpath};
    my $minsize = $camera->{minsize};
    my $maxsize = $camera->{maxsize};
    my $dh      = DirHandle->new($dir);
    my @stat;

    my $chunkSize=128;
    my $cnt=0;

    print "Scanning $dir \n";
    while ( defined( $_ = $dh->read() ) && $cnt < $chunkSize ) {
        next unless (/\.jpg$/i);

        my $full_path = File::Spec->catfile( $dir, $_ );
        @stat = ( stat $full_path );
        my $bytes = $stat[7];
        if ( $bytes < $minsize ) {
            log( MotionProxy::Constant::LOGNAME,
                "Bytes: $bytes < $minsize, $full_path. " );
            unlink $full_path;
            ++$self->{skipped};
            ++$self->{minsize_events};
            next;
        }
        if ( $bytes > $maxsize ) {
            log( MotionProxy::Constant::LOGNAME,
                "Bytes: $bytes > $maxsize, $full_path. " );
            unlink $full_path;
            ++$self->{skipped};
            ++$self->{maxsize_events};
            next;
        }
        my $time = $stat[10];
        my $obj = new MotionProxy::QueueObject( $self, $full_path, $time, $bytes );
        $self->enqueue( $obj );
        ++$cnt;
    }
    $self->sort();
#    if ($main::Debug) {$self->p();}
    print "Got $cnt files. \n";
    return $cnt;
}


sub enqueue {
    my $self = shift;
    my $obj  = shift;
    push @{$self->{data}}, $obj;
}

sub dequeue {
    my $self = shift;
    my $ar   = $self->{data};
    return pop @{$self->{data}};
}

sub next {
    my $self = shift;
    my $ar   = $self->{data};
    my $n    = scalar @{$ar};

    if ( $n < 1 ) {
        $self->{last} = undef;
        $self->fill();
    }
    my $obj = shift @{$ar};
    $self->{last} = $obj;
    return $self->{last};
}


sub p {
  my $self=shift;
  print "camera = ", $self->{camera}, " .\n";
}


1;


__END__

