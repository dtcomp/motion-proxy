package MotionProxy::Camera;

# This represent the http: camera's data source
#use strict;
#use diagnostics;
#use warnings;

use strict;
use warnings;
use Switch;
use Data::Dumper;
use File::Spec;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;
use File::stat;
use Fcntl ':mode';
use Log::Lite qw(logrotate logmode logpath log);

use MotionProxy::Queue;
use MotionProxy::Constant;

#BEGIN {
#    our %Configurables=(
    
our %Configurables=(
'name' => 'template' ,
'path' => MotionProxy::Constant::CAMPATH,
'port' => 8080,
'base' => '/tmp',
'minsize' => 7001,
'maxsize' => 200001,
'default_img' => 'default.jpg',
'last_img' => MotionProxy::Constant::LASTFILENAME,
'aliases' => undef,
'minsize_events' => 0,
'maxsize_events' => 0
    );
    
our @Derivatives=( 'objpath', 'inpath', 'tmppath', 'queue', 'aliases' );
our %Aliases;
our @Instances;


sub StartAll {
  for my $cam (our @Instances) {  
    $cam->start();
  }
}

sub new {
  my $class=shift;
  my $options=shift;
  
  my %self=%MotionProxy::Camera::Configurables; # start with defaults
  my $self=\%self;
  my $x = ref $options;
  
  unless ( "$x" eq "HASH" ) {
    die( "Options isa ", $x , "\n");
  }
  
  my $k;
#  print "Options: ", Dumper($options), "\n";
  foreach $k (keys $options) {
#    print "Optionkey: ", $k, "\n";
    if ( exists $MotionProxy::Camera::Configurables{$k} ) {
      $x = ref $options->{$k};
      unless ($x) {
        $x='None';
      }
#      print "ref $k = ", $x, "\n";
      switch ($x) {
        case 'ARRAY'  {
          my @tmp;
          $self->{$k} = \@tmp;
          @tmp = @{$options->{$k}};
        }
        case 'None' {
          $self->{$k} = $options->{$k};
#          print "$self->{$k} = $options->{$k}", "\n";
        }
        case 'HASH' {
           die("HASH unexpected...");
        }
      }
    } else {
       if ( exists $MotionProxy::Camera::Derivatives{$k} ) {
      $x = ref $options->{$k};
      unless ($x) {
        $x='None';
      }
#      print "ref $k = ", $x, "\n";
      switch ($x) {
        case 'ARRAY'  {
          my @tmp;
          $self->{$k} = \@tmp;
          @tmp = @{$options->{$k}};
        }
        case 'None' {
          $self->{$k} = $options->{$k};
#          print "$self->{$k} = $options->{$k}", "\n";
        }
        case 'HASH' {
           die("HASH unexpected...");
        }
      }
    } else {
    die("Bad options key: $k");
    }
  }
#  print "CAM: ", Dumper($self), "\n";
  }
  
  MotionProxy::Camera::aliasCheck($self);
  
  bless $self, $class;
  return $self->initialize();
}

sub aliasCheck {
  my $self=shift;
        for my $a ( @{$self->{aliases}} ) {
          if ( exists $MotionProxy::Camera::Aliases{$a} ) {
            die("Duplicate Alias: $self->{name}, $a , previously defined in: ",$MotionProxy::Camera::Aliases{$a} );
          } else {
            $MotionProxy::Camera::Aliases{$a}=$self->{name};
          }
        }
      }

sub minsizeEvent {
  my $self=shift;
  $self->{minsize_events}++;
}

sub maxsizeEvent {
  my $self=shift;
  $self->{maxsize_events}++;
}

sub initialize {
  my $self=shift;
  
  $self->mkdirs();  
  if (defined $self->{default_img}) {
        if ( -e $self->{default_img} ) {
            my $imgbase = basename($self->{default_img});
            my $newpath = File::Spec->catfile( $self->{tmppath}, $imgbase );
            copy($self->{default_img}, $newpath );
            # rebase the image path to the tmp dir
            $self->{default_img} = $newpath;
            # stub a last image
            my $last = File::Spec->catfile( $self->{tmppath}, 'last.jpg' );            
            copy( $self->{default_img}, $last );
            $self->{last_img} = $last;
        } else {
        log(MotionProxy::Constant::LOGNAME, "default image $self->{default_img} not found");
        }
    }
    no strict 'subs';
    push @Instances, $self;
 
    return $self;
}

sub start {
  my $self=shift;
   $self->{queue}=new MotionProxy::Queue($self);
}


sub stop {
   my $self=shift;
   $self->{queue}->stop();
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
  print "mins: $self->{maxsize}\n";
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

# print __FILE__ . ": @INC: \n";

1;

__END__
