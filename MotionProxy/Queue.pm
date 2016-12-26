package MotionProxy::Queue;
use threads (
    'yield',
    'stack_size' => 128 * 4096,
    'exit'       => 'threads_only',
    'stringify'
);
use strict;
use diagnostics;
use warnings;

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;       # no deeper than 3 refs down

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
#use Carp;


our %Instances;

sub StartAll {
    for my $q ( values %Instances ) {
        $q->start();
    }
}

sub new {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;
    print "Options: $name: ", Dumper($options), "\n";
    my %cameras = ();

    my $self = bless {
        name    => $name,
        port    => $options->{port},
        cameras => \%cameras,
        daemon  => undef,
        thread  => undef,
    }, $class;

    $self->initialize($options);
    $Instances{$self->{name}} = $self;
    return $self;
}

sub initialize {
    my $self = shift;
    my $options = shift;

    if ( defined ($options->{cameras}) ) {
      for my $c ( split(' ', $options->{cameras}) ) {
          $self->{cameras}->{$c} = undef;
      }
    }
}

sub start {
    my $self = shift;

      for my $c ( keys $self->{cameras})  {
        my $r = MotionProxy::Camera::ResolveAlias($c);
        if ( defined($r) ) {
          my $qd = new MotionProxy::QueueData( $r );
          if (! $c eq $r){
            delete $self->{cameras}->{$c};
          }
          $self->{cameras}->{$r} = $qd;
          $qd->fill();
        } else {
          print "Bad Camera name: $c .\n";
        }
      }
    $self->{thread} = async { $self->run(); };
    $self->{thread}->yield();
}


sub p {
    my $self = shift;

    print "port  ", $self->{port}, "\n";
}

use POSIX qw(:sys_wait_h);

sub run {
    my $self = shift;
    $self->{daemon} = HTTP::Daemon->new(
        #	  LocalAddr => 'localhost',
        LocalPort => $self->{port},
        ReuseAddr => 1
    ) || die("Could not start HTTP");

    my $daemon=$self->{daemon};
    my $conn = undef;

    print "Wait for accept \n";
    yield();

    while ( $conn = $daemon->accept() ) {
        my $request = undef;
        print "Connect from host: ", $conn->peerhost(), " .\n";
        while ( $request = $conn->get_request() ) {
          #	  my $rhost = $request->uri->host;
          #	  my $rport = $request->uri->port;
          # my $rpath = $request->uri->path;
          if ( $request->method eq 'GET' ) {
            my $cam_name = MotionProxy::Camera::ResolveAlias( (split('/', dirname($request->uri->path)))[-1]);
            if ( !defined( $cam_name )) {
              print "Cannot find camera: ", $cam_name , ". \n";
              $conn->send_error(RC_NOT_FOUND);
              last;
            }
            my $qdata = $self->{cameras}->{$cam_name};
#            print "Req:  " , Dumper($request), "\n";
            my $obj = $qdata->next();
#           print "Req:  " , Dumper($request), "\n";
            if ( defined($obj) ) {
              my $file = $obj->name();
              if ( $file && -e $file) {
                $conn->send_file_response($file);
              } else {
                print("Error: No file disappeared?  ($file)\n");
                $conn->send_error(500);
              }
              $obj->done();
            } else {    # out of files to send...
              my $cam = MotionProxy::Camera::ResolveAliasRef($qdata->{camera});
              print "out of files for $cam_name .\n";
		      if ( $cam->{default_img} && -r $cam->{default_img} ) {
                $conn->send_file_response($cam->{default_img} );
		      } else {
                $conn->send_error(RC_NOT_FOUND);
		      }
            }
          } else {
            print "Got here 2: 403 (" , $request->uri->path, ") .\n";
            $conn->send_error(RC_FORBIDDEN);
          }
#          my $cn = $request->header('connection');
#            print "Connection: $cn .\n";
        }
    }
  print __FILE__ . ":" . __LINE__, "UHOH, something bad happened...\n";
}

sub stop {
    my $self = shift;
    die("Stop Not Implemented");
}

# print __FILE__ . ": @INC: \n";

1;

__END__
