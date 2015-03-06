use Symbol;
use POSIX;


$PREFORK	= 2;
$CLIENTS	= 2;
%CHILDREN	= {};
$CHILDREN	= 0;


sub cleanup {
  local($SIG{CHLD}) = 'IGNORE';
  kill 'INT' => keys %CHILDREN;
  exit;
}

# somebody just died.  keep harvesting the dead until 
# we run out of them.  check how long they ran.

sub reaper {
     my $child;
     my $start;
     while (($child = waitpid(-1,WNOHANG)) > 0) {
         if ($start = $CHILDREN{$child}) {
             my $runtime = time() - $start;
             printf "Child $child ran %dm%ss\n", $runtime / 60, $runtime % 60;
             delete $CHILDREN{$child};
         } else {
             print "Bizarre kid $child exited $?\n";
         } 
     }
     $SIG{CHLD} = \&reaper;
}


package MotionProxyCameraServer;
#use strict;
#use diagnostics;
#use warnings;
#use HTTP::Server::Multiplex;

use HTTP::Daemon;
use HTTP::Request::Params;
use HTTP::Status;
use Data::Dumper;
use MotionProxy::Camera;

#print "@INC: ", Dumper(@INC), "\n";

sub new {
  my $class=shift;
  my $camera=shift;# owned by MotionProxyCamera

  my $daemon=undef;
  my $conn=undef;
  my %children={};
  
  my $self = bless {
    camera => $camera,
    daemon => $daemon,
    conn   => $conn,
	children => $children
  }, $class;
  
  $self->initialize();
  return $self;
}

sub initialize {
  my $self=shift;
  
  my $server = $self->new_daemon();
  for (1 .. 2) {
    print "forking %  \n";
    $self->new_child( $server );
  }

  $SIG{CHLD} = \&reaper;  
  $SIG{INT}  = \&cleanup;
#  $SIG{TERM} = \&cleanup;
}

sub new_daemon {
  my $self=shift;
  $self->{daemon} = HTTP::Daemon->new(
#	LocalAddr => 'localhost',
	LocalPort => $self->{camera}->{port},
	ReuseAddr => 1
  ) || die;
  print "Please contact ", $self->{camera}->{name},  "  at ", $self->{daemon}->url, "\n";
  return $self->{daemon};
}

sub handle_request {
  my $self=shift;
  my $conn=shift;
  
  my $path = $self->{camera}->{path};
  while (my $request = $conn->get_request) {
	  my $host = $request->uri->host;
	  my $port = $request->uri->port;
	  my $path = $request->uri->path;
      if ($request->method eq 'GET' and $path eq "/snapshot.cgi" ) {
		my $obj = $self->{camera}->next();
	    my $file = $obj->name;
	    if ($file) {
		print "Sending: ", $file, "  \n";
          $self->{conn}->send_file_response( $file );
        } else {
		  die("No file to send!.\n");
	    }
	  } else {
	    print "Got here 2: 403 ($path) \n";
        $c->send_error(RC_FORBIDDEN)
      }
      print "Got here 3 \n";
#      $c->force_last_request;
    }
    print "Got here 4 \n";
    $self->{conn}->close();
    undef($self->{conn});
}


sub new_child {
    my $self=shift;
	my $server=shift;
    my $pid;
    my $sigset;
    
    # block signal for fork
#    $sigset = POSIX::SigSet->new(SIGINT);
#    sigprocmask(SIG_BLOCK, $sigset) or die "Can't block SIGINT for fork: $!\n";
    
    die "fork: $!" unless defined ($pid = fork);
		print "Going to handle some.. ", $pid , "\n";    
    if ($pid) {
        # Parent records the child's birth and returns.
#        sigprocmask(SIG_UNBLOCK, $sigset) or die "Can't unblock SIGINT for fork: $!\n";
        $CHILDREN{$pid} = 1;
        $CHILDREN++;
        return;
    } else {
        # Child can *not* return from this subroutine.
#        $SIG{INT} = 'DEFAULT';      # make SIGINT kill us as it did before
        # unblock signals
#        sigprocmask(SIG_UNBLOCK, $sigset) or die "Can't unblock SIGINT for fork: $!\n";

		print "Going to handle some.. ", $pid , "\n";
        # handle connections until we've reached $MAX_CLIENTS_PER_CHILD
        for ($i=0; $i < 2; $i++) {
            $client = $server->accept() or last;
            $self->handle_request($client);
        }
    
        # tidy up gracefully and finish
    
        # this exit is VERY important, otherwise the child will become
        # a producer of more and more children, forking yourself into
        # process death.
        exit;
    }
}

sub serve {
  my $self=shift;
  my $pid;
  
  $SIG{CHLD}=\&reaper;
  my $conn;
  while ($conn = $self->{daemon}->accept) {
    next if $pid = fork;
	die "fork: $!" unless defined $pid;
	$self->handle_request($conn);
	exit;
  } continue {
      print "GOT HERE " , __FILE__, ':',  __LINE__, "  \n";
      $conn->close();
    } 
}






1;


__END__


#      my ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df($basedir);
#      print "df: $fs_type, $fs_desc, $used, $avail, $fused, $favail  \n";
