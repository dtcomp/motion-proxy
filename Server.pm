package MotionProxyServer;
#use strict;
#use diagnostics;
#use warnings;
use POSIX "setsid";
use Data::Dumper;
use Filesys::DiskSpace;
use MotionProxy::Camera;
use Log::Lite qw(logrotate logmode logpath log);

#print "@INC: ", Dumper(@INC), "\n";

sub new {
  my $class=shift;
  my $name=shift;
  my $base=shift;
  my $portbase=shift;
  my $minsize_default=shift;
  my $portcurrent=$portbase;

  my @cameras=[];

  my $self = bless {
    name => $name,
    base => $base,
	portbase => $portbase,
	portcurrent => $portcurrent,
    minsize_default => $minsize_default,
    cameras => @cameras    
  }, $class;
 
 $self->initialize();
 return $self;
}

sub p {
  my $self=shift;

  print "name: $self->{name}\n";
  print "base: $self->{base}\n";
}

sub initialize {
  #logrotate("year");            #autocut logfile every year 
  logrotate("no");              #disable autocut
  logmode("log");               #log in file (Default)
  #logmode("debug");             #output to STDERR
  #logmode("slient");            #do nothing
  logpath("/tmp/");    #defined where log files stored
  #logsregex("stopword");                #set a regex use to remove words that you do not want to log. Default is [\r\n\t]
  log("motion-proxy", "motion proxy initialized.", "dfgd", "script");
}

sub createCameraServer {
  my $self=shift;
  my $name=shift;
  my $path=shift;
  my @aliases=@_;

  my $camera = new MotionProxyCamera( $name, $path, $self->{portcurrent}, $self->{base}, $self->{minsize_default}, undef, \@aliases );
  push $self->{cameras}, $camera;
  ++$self->{portcurrent};
}


sub run {



}


1;


__END__



