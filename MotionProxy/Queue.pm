package MotionProxy::Queue;
 use threads ('yield',
'stack_size' => 128*4096,
'exit' => 'threads_only',
'stringify');
use strict;
use diagnostics;
use warnings;
#use Data::Dumper;
use Log::Lite qw(logrotate logmode logpath log);
use HTTP::Daemon;
use HTTP::Request::Params;
use HTTP::Status;
use DirHandle;
use File::Copy;
use MotionProxy::QueueObject;
use MotionProxy::Constant;

sub new {
  my $class=shift;
  my $camera=shift;  # MotionProxyCamera
  my $data=[];
  my $skipped=0;
  my $total=0;
  my $last=undef;
  my $daemon=undef;
  my $thread=undef;


  my $self = bless {
    camera  => $camera,
	data    => $data,
	skipped => $skipped,
	last    => $last,
	total   => $total,
	daemon  => $daemon,
	thread  => $thread
  }, $class;
  
  $self->initialize();
  return $self;
}

sub initialize {
  my $self=shift;
  
  $self->fill();
  $self->{thread} =  async { $self->run(); };
  print "GOT HERTE\n";
  $self->{thread}->yield();
#  $self->run();
}

sub p {
  my $self=shift;
  
  print "camera  ", $self->{camera}, "\n";
  my $ar=$self->{data};
  print "data    ", @$ar[0],  "\n";
  print "last    ", $self->{last}, "\n";
  print "total   ", $self->{total}, "\n";
  print "skipped ", $self->{skipped}, "\n";
  print "daemon  ", $self->{daemon}, "\n";
}

sub sort {
  my $self=shift;
  my $ar = $self->{data};
  @{$ar} = sort { return  $a->{time} <=> $b->{time}; } $ar;
}

sub fill {
  my $self=shift;
  my $dir = $self->{camera}->{inpath};
  my $dh = DirHandle->new($dir);
  my $minsize=$self->{camera}->{minsize};
  my $maxsize=$self->{camera}->{maxsize};
  my @stat;
  
  while ( defined( $_ = $dh->read() )) {
    next unless (/\.jpg$/i);
 #   print "$dir : file= $_ \n";
    my $full_path = File::Spec->catfile($dir, $_);
    @stat = (stat $full_path);
    my $bytes = $stat[7];
    if ( $bytes < $minsize ) {
      log(MotionProxy::Constant::LOGNAME,"Bytes: $bytes < $minsize, $full_path. ");
      unlink $full_path;
      ++$self->{skipped};
      $self->{camera}->minsizeEvent();
      next;
    }
    if ( $bytes > $maxsize ) {
      log(MotionProxy::Constant::LOGNAME,"Bytes: $bytes > $maxsize, $full_path. ");
      unlink $full_path;
      ++$self->{skipped};
      $self->{camera}->maxsizeEvent();
      next;
    }
    my $time = $stat[10];
    $self->enqueue( new MotionProxy::QueueObject( $self, $full_path, $time, $bytes ) );
  }
  $self->sort();
}

sub enqueue {
  my $self=shift;
  my $obj=shift;
  my $ar=$self->{data};
  push $ar, $obj;
}

sub dequeue {
  my $self=shift;
  my $ar=$self->{data};
  return pop $ar;
}

sub next {
  my $self=shift;
  my $ar=$self->{data};
  my $n=scalar @$ar;

  if ($n < 1 ) {
    $self->{last}=undef;
    $self->fill();
  }
  my $obj = shift $ar;
  $self->{last} = $obj;
  return $self->{last};
}


use POSIX qw(:sys_wait_h);

sub run {
  my $self=shift;
  my $daemon;
  my $sport=$self->{camera}->{port};
  
    $daemon = HTTP::Daemon->new(
#	  LocalAddr => 'localhost',
	  LocalPort => $self->{camera}->{port},
	  ReuseAddr => 1
    ) || die;

  print "Please contact ", $self->{camera}->{name},  "  at ", $daemon->url, "\n";
  my $path = $self->{camera}->{path};
  my $conn=undef;

  print "Wait for accept \n";
  yield();
 
  while  ( $conn = $daemon->accept() ) {
#	print "Connect from host: ", $conn->peerhost(), "$sport .\n";
    while (my $request = $conn->get_request) {
#	  my $rhost = $request->uri->host;
#	  my $rport = $request->uri->port;
	  my $rpath = $request->uri->path;
      if ($request->method eq 'GET' and $rpath eq $path ) {
		my $obj = $self->next();
		if (defined($obj)) {
	      my $file = $obj->{name};
	      if ($file) {
#		    print "Sending: ", $file, "  \n";
            $conn->send_file_response( $file );
			$obj->done();
#		    yield();
          } else {
		    print("No filename to send!???.\n");
			$conn->send_error(500);
#			yield();
	      }
		} else {  # out of files to send...
		  print "out of files...\n";
#		  $conn->send_error(RC_NOT_FOUND);
#		  yield();
		}
		print "got here 1\n";
	  } else {
	    print "Got here 2: 403 ($rpath) \n";
        $conn->send_error(RC_FORBIDDEN);
#		 $conn->send_response(RC_NOT_MODIFIED);
#		yield();
      }
	  print "got here 3 \n";
    }
    print "Got here 4 \n";
#    if ($conn) {
#	   print "Closing conn.\n";
#	   $conn->force_last_request;
#       $conn->close();
#       undef($conn);
#     }
  } 
  print "UHOH, something bad happened...\n";
}

sub stop {
  my $self=shift;
  die(" stop Not Implemented");
}

# print __FILE__ . ": @INC: \n";

1;


__END__
