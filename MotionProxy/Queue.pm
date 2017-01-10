package MotionProxy::Queue;

use Carp;
use strict;
use diagnostics;
use warnings;
use Data::Dumper;
use Log::Lite qw(logrotate logmode logpath log);
use HTTP::Daemon;
use HTTP::Request::Params;
use HTTP::Status;
use DirHandle;
use File::Copy;
use File::Basename;

use MotionProxy::QueueObject;
use MotionProxy::QueueData;
use MotionProxy::Constant;

use threads (
  'yield',
  'stack_size' => 128 * 4096,
  'exit'       => 'threads_only',
  'stringify'
);

$Data::Dumper::Maxdepth = 2;    # no deeper than 3 refs down

our $VERSION = 1.0611;
our %Instances;

sub StartAll {
  for my $q ( values %Instances ) {
    print "Starting $q->{name} \n";
    $q->{thread} = async { $q->start(); };
  }

  for my $q ( values %Instances ) {
    $q->{thread}->join();
    print "$q->{name} joined! .\n";
  }

#  while (1) {
#    if ( $self->{thread} ) {
#      if ( $self->{thread}->is_running() ) {
#        sleep(2);
#      }
#      else {
#        print "Thread exited, restarting ...\n";
#        $self->{conn}->force_last_request();
#        $self->{conn}->close();
#
#        undef $self->{conn};
#        undef $self->{daemon};
#        $self->start_thread();
#      }
#    }
#    else {
#      $self->start_thread();
#    }
#  }

}

sub new {
  my $class   = shift;
  my $name    = shift;
  my $options = shift;
#  print "Options: $name: ", Dumper($options), "\n";
  my %cameras = ();

  my $self = bless {
    name    => $name,
    port    => $options->{port},
    cameras => \%cameras,
    daemon  => undef,
    conn    => undef,
    thread  => undef,
  }, $class;

  $self->initialize($options);
  $Instances{ $self->{name} } = $self;
  return $self;
}

sub initialize {
  my $self    = shift;
  my $options = shift;

  if ( defined( $options->{cameras} ) ) {
    for my $c ( split( ' ', $options->{cameras} ) ) {
      $self->{cameras}->{$c} = undef;
    }
  }
}

sub start {
  my $self = shift;

  for my $c ( keys $self->{cameras} ) {
    my $r = MotionProxy::Camera::ResolveAlias($c);
    if ( defined($r) ) {
      my $qd = new MotionProxy::QueueData($r);
      if ( !$c eq $r ) {
        delete $self->{cameras}->{$c};
      }
      $self->{cameras}->{$r} = $qd;
      $qd->fill();
    }
    else {
      print "Bad Camera name: $c .\n";
    }
  }
  $self->{daemon} = HTTP::Daemon->new(
    LocalPort => $self->{port},
    ReuseAddr => 1
  ) || die("Could not start HTTP");
  $self->run();
}

sub p {
  my $self = shift;

  print "port  ", $self->{port}, "\n";
}

use POSIX qw(:sys_wait_h);


sub run {
  my $self = shift;
  my $daemon = $self->{daemon};

  print $self->{name}, " Wait for accept \n";
  while ( my $conn = $daemon->accept() ) {
#    print "Connect from host: ", $conn->peerhost(), " .\n";
#    print '.';
    threads->create( \&serve, $self, $conn )->detach();
  }
}

sub serve {
    my $self=shift;
    my $conn=shift;
    threads->set_thread_exit_only(1);
    my $request = $conn->get_request();
      if ( $request->method eq 'GET' ) {
        my $cam_name = MotionProxy::Camera::ResolveAlias(
          ( split( '/', dirname( $request->uri->path ) ) )[-1] );
        if ( !defined($cam_name) ) {
          print "Cannot find camera: ", $cam_name, ". \n";
          $conn->send_error(RC_NOT_FOUND);
          $conn->close();
          undef $conn;
          next;
        }
        my $qdata = $self->{cameras}->{$cam_name};
        my $obj = $qdata->next();
        if ( defined($obj) ) {
          my $file = $obj->name();
          if ( -r $file ) {
            $conn->send_file_response($file);
          }
          else {
            print "Error: File disappeared..  ($file)\n";
            $conn->send_error(RC_NOT_FOUND);
          }
            print "Dequeue:..  ($file)\n";
          $qdata->dequeue();
        }
        else {    # out of files to send...
            my $cam = MotionProxy::Camera::ResolveAliasRef( $qdata->{camera} );
            if ( -r $cam->{default_img} ) {
              $conn->send_file_response( $cam->{default_img} );
            }
            else {
              $conn->send_error(RC_NOT_FOUND);
            }
        }
      }
      else {
          print 'Got here 2: 403 (', $request->uri->path, ') .\n';
          $conn->send_error(RC_FORBIDDEN);
      }
    $conn->close();
    undef $conn;
}

sub stop {
    my $self = shift;
    die("Stop Not Implemented");
}

# print __FILE__ . ": @INC: \n";

1;

__END__
