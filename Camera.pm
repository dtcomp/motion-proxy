
sub byctime
{
   return  $a->{time} <=> $b->{time};
}

package MotionProxyCamera;

# This represent the http: camera's data source
#use strict;
#use diagnostics;
#use warnings;

use Data::Dumper;
use File::Spec;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;
use File::stat;
use Fcntl ':mode';
use Filesys::DiskSpace;
use MotionProxy::Queue;

#use MotionProxyCameraServer;

#print "@INC: ", Dumper(@INC), "\n";

sub new {
  my $class=shift;
  my $name=shift;
  my $path=shift;        # CGI/request path
  my $port=shift;
  my $base=shift;        # Base for files only, WITHOUT camera name
  my $minsize=shift;
  my $default_img=shift; # send this if no image available, ever
  my $aliases=shift;
  my $last_img=undef;    # send this if images run out (keep last one)
  my $objpath=undef;     # derived path, including cam name
  my $inpath=undef;      # derived as above/in
  my $tmppath=undef;     # derived as above/tmp
  my $queue=undef;
  my $server=undef;

  my $self = bless {
    name => $name,
	path => $path,
	port => $port,
    base => $base,
    minsize => $minsize,
    default_img => $default_img,
    last_img => $last_img,
    objpath => $objpath,
    inpath => $inpath,
    tmppath => $tmppath,
    queue => $queue,
	server => $server,
	aliases => $aliases
  }, $class;

  $self->initialize();

 return $self;
}

sub initialize {
  my $self=shift;
#  foreach my $alias (@aliases) {
#    $self->addAlias($alias,$camera);
#  }
  $self->mkdirs();  
  if (defined $self->{default_img}) {
    if ( -e $self->{default_img} ) {
      my $imgbase = basename($self->{default_img});
	  my $newpath = File::Spec->catfile( $self->{tmppath}, $imgbase );
      copy($self->{default_img}, $newpath );
      # rebase the image path to the tmp dir
      $self->{default_img} = $newpath;
      # stub a last image
	  my $last = File::Spec->catfile( $self->{tmppath}, "last.jpg" );
      copy( $self->{default_img}, $last );
	  $self->{last_img} = $last;
    }
  }
  $self->{queue}=new MotionProxyQueue($self, byctime);
}




sub next {
   my $self=shift;
   
  return $self->{queue}->next();
}
sub p {
  my $self=shift;

  print "name: $self->{name}\n";
  print "base: $self->{base}\n";
  print "mins: $self->{minsize}\n";
  print "defi: $self->{default_img}\n";
  print "last: $self->{last_img}\n";
  print "ogjp: $self->{objpath}\n";
  print "inpp: $self->{inpath}\n";
  print "tmpp: $self->{tmppath}\n";
  print "queu: $self->{queue}\n";
}

sub mkdirs {
  my $self=shift;
  my ($link, $s1, $s2);
 
  $s1=(stat($self->{base}));
  if ( $s1 ) {    # base already exists
     unless ( $s1->cando(S_IWUSR,1) ) {
	   die("Permissions problem: Cannot write to $self->{base}. \n");
	 }
	# see if base is dir or symlink to ... tmpfs perhaps?

    if ( !S_ISDIR($s1->mode) and !S_ISLNK($s1->mode) ) {
      die("$self->{base} exists and is not a directory or symbolic link, modes=",  $s1->mode+' ', "  . \n");
    }
    if ( S_ISLNK($s1->mode)) {
      $s2=(lstat($self->{base}));
      $link=readlink $self->{base};
      $self->{base} = $link;
    }
  } else {
    make_path($self->{base}) || die("Cannot make base directory $self->{base}.\n");
  }
  $self->{objpath} = File::Spec->catfile( $self->{base},  $self->{name} );
  if ( ! -e $self->{objpath}) {
    make_path($self->{objpath}) || print("Cannot make $self->{objpath}.\n");
  }
  $self->{inpath} = File::Spec->catfile($self->{objpath},"in");
  if ( ! -e $self->{inpath}) { 
    make_path( $self->{inpath} ) || die("Cannot make $self->{inpath}. \n");
  }
  $self->{tmppath} = File::Spec->catfile($self->{objpath},"tmp");
  if ( ! -e $self->{tmppath}) {   
    make_path( $self->{tmppath} ) || die("Cannot make $self->{tmppath}. \n");
  }
  
  return 1;
}


1;

__END__
