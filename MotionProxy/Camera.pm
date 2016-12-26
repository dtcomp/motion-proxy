package MotionProxy::Camera;

# This represents the http: camera's data source
use strict;
use diagnostics;
use warnings;

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
use MotionProxy::Constant;


our %Configurables = (
    'name'           => undef,
    'base'           => undef,
    'path'           => MotionProxy::Constant::CAMPATH,
    'minsize'        => 7001,
    'maxsize'        => 200001,
    'default_img'    => 'default.jpg',
    'last_img'       => MotionProxy::Constant::LASTFILENAME,
    'aliases'        => {},
    'active'         => 1
);

our %Derivatives = ( 'objpath' => undef, 'inpath' => undef, 'tmppath' => undef);
our %Aliases;
our %Instances;

#sub StartAll {
#    for my $cam ( values %Instances ) {
#      if ( $cam->{active} ) {
#        $cam->{queue} = $queue;
#        $cam->start();
#      }
#    }
#    $queue->start();
#}

sub ResolveAlias {
  my $name = shift;
  
  return $Aliases{$name}->{name};
}

sub ResolveAliasRef {
  my $name = shift;
  
  return $Aliases{$name};
}

sub new {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;
    my %self;
    my $self = \%self;
    
    # Copy defaults from template
    foreach my $k ( keys %MotionProxy::Camera::Configurables ) {
        my $c = $MotionProxy::Camera::Configurables{$k};
        my $x = ref $c;
        unless ($x) { $x = 'None'; }
        switch ($x) {
          case 'ARRAY' {
            my @a;
            foreach my $e ( $c ) {
              push @a, $e;
            }
            $self->{$k} = \@a;
          }
          case 'None' {
            $self->{$k} = $MotionProxy::Camera::Configurables{$k};
          }
          case 'HASH' {
            my %h;
            foreach my $e ( keys $c ) {
              $h{$e} = $c->{$e};
            }
            $self->{$k} = \%h;
          }
        }
    }
 
    $self->{name} = $name;
    $self->{aliases}->{$name} = $name;
    my $x    = ref $options;
    my $x2;

    print "Options: ", Dumper($options), "\n";

    unless ( "$x" eq "HASH" ) {
        die( "Options isa ", $x, ", expected HASH\n" );
    }

    foreach my $k ( keys $options ) {
      print "Optionkey: ", $k, "\n";
      if ( exists $MotionProxy::Camera::Configurables{$k} ||
           exists $MotionProxy::Camera::Derivatives{$k} ) {
        $x = ref $options->{$k};
        $x2 = ref $self->{$k};
        unless ($x2) { $x2 = 'None'; }
        unless ($x) { $x = 'None'; }
        print "ref1 $k = ", $x, "\n";
        print "ref2 Conf $k = ", $x2 , "\n";
        switch ($x2) {
          case 'ARRAY' {
            if ( "$x" eq 'None' ) {
              push $self->{$k}, $options->{$k};
            }
          }
          case 'None' {
            $self->{$k} = $options->{$k};
            print "$self->{$k} = $options->{$k}", " None\n";
          }
          case 'HASH' {
            if ( "$x" eq 'None' ) {
              $self->{$k}{$options->{$k}} = $name;
            }
          }
        }
      } else {
        die("Bad options key: $k");
      }
    print "CAM: ", Dumper($self), "\n";
  }
  bless $self, $class;
  return $self->initialize();
}

sub aliasCheck {
  print "ALIAS: ", Dumper(%MotionProxy::Camera::Aliases), "\n";
  my $self = shift;
  for my $a ( keys $self->{aliases} ) {
    if ( exists $MotionProxy::Camera::Aliases{$a} ) {
        die( "Duplicate Alias: $self->{name}, $a , previously defined in: ",
             $MotionProxy::Camera::Aliases{$a}->{name} );
    }
    else {
        $MotionProxy::Camera::Aliases{$a} = $self;
	    print "Adding alias $a => $self->{name} \n";
    }
  }
}



sub initialize {
    my $self = shift;
    MotionProxy::Camera::aliasCheck($self);
    $self->mkdirs();
    if ( defined $self->{default_img} ) {
        if ( -e $self->{default_img} ) {
            my $imgbase = basename( $self->{default_img} );
            my $newpath = File::Spec->catfile( $self->{tmppath}, $imgbase );
            copy( $self->{default_img}, $newpath );

            # rebase the image path to the tmp dir
            $self->{default_img} = $newpath;

            # stub a last image
            my $last = File::Spec->catfile( $self->{tmppath}, 'last.jpg' );
            copy( $self->{default_img}, $last );
            $self->{last_img} = $last;
        }
        else {
            log( MotionProxy::Constant::LOGNAME,
                "default image $self->{default_img} not found" );
        }
    }
    no strict 'subs';
    $Instances{$self->{name}} = $self;
    print "CONFIGURABLES: ", Dumper(%Configurables), "\n";
    return $self;
}

sub start {
    my $self = shift;
}

sub stop {
    my $self = shift;
 #   $self->{queue}->stop();
}

sub p {
    my $self = shift;

    print "name: $self->{name}\n";
    print "base: $self->{base}\n";
    print "mins: $self->{minsize}\n";
    print "mins: $self->{maxsize}\n";
    print "defi: $self->{default_img}\n";
    print "last: $self->{last_img}\n";
    print "ogjp: $self->{objpath}\n";
    print "inpp: $self->{inpath}\n";
    print "tmpp: $self->{tmppath}\n";
}

sub mkdirs {
    my $self = shift;
    my ( $link, $s1, $s2 );

    if ( defined $self->{base} ) {
    $s1 = ( stat( $self->{base} ) );
    if ($s1) {    # base already exists
        unless ( $s1->cando( S_IWUSR, 1 ) ) {
            die("Permissions problem: Cannot write to $self->{base}. \n");
        }

        # see if base is dir or symlink to ... tmpfs perhaps?

        if ( !S_ISDIR( $s1->mode ) and !S_ISLNK( $s1->mode ) ) {
            die( "$self->{base} exists and is not a directory or symbolic link, modes=",
                $s1->mode + ' ',
                "  . \n"
            );
        }
        if ( S_ISLNK( $s1->mode ) ) {
            $s2           = ( lstat( $self->{base} ) );
            $link         = readlink $self->{base};
            $self->{base} = $link;
        }
    }
    else {
        make_path( $self->{base} )
          || die("Cannot make base directory $self->{base}.\n");
    }
      $self->{objpath} = File::Spec->catfile( $self->{base}, $self->{name} );
          if ( ! -e $self->{objpath} ) {
        make_path( $self->{objpath} ) || print("Cannot make $self->{objpath}.\n");
    }
    if ( ! defined($self->{inpath} ) ) {
      $self->{inpath} = File::Spec->catfile( $self->{objpath}, "in" );
    }
    if ( ! defined( $self->{tmppath} )) {
      $self->{tmppath} = File::Spec->catfile( $self->{objpath}, "tmp" );
    }
  }

    if ( !-e $self->{inpath} ) {
        make_path( $self->{inpath} ) || die("Cannot make $self->{inpath}. \n");
    }
 
    if ( !-e $self->{tmppath} ) {
        make_path( $self->{tmppath} )
          || die("Cannot make $self->{tmppath}. \n");
    }

    return 1;
}

# print __FILE__ . ": @INC: \n";

1;

__END__
