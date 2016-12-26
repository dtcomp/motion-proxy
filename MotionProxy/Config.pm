package MotionProxy::Config;
use MotionProxy::Camera;
use MotionProxy::Queue;

use strict;
use Switch;
use diagnostics;
use warnings;

use Log::Lite qw(logrotate logmode logpath log);
use Config::General;

# From http://search.cpan.org/~tlinden/Config-General-2.60/General/Extended.pm
use Data::Dumper;

sub new {
    my $class    = shift;
    my $file     = shift;
    my $defaults = shift;
    my %rootvalues;
    my $self = bless {
        file  => $file,
        conf  => undef,
        data  => undef,
        value => \%rootvalues
    }, $class;
    $self->setDefaults($defaults);
    $self->initialize();

    return $self;
}

sub setDefaults {
    my $self = shift;
    my $href = shift;

    #  print "href: ", Dumper($href), "\n";
    for my $k ( keys %{$href} ) {
        print "Setting default for $k => $href->{$k} \n";
        $self->{value}->{$k} = $href->{$k};
    }
}

sub get {
    my $self = shift;
    my $key  = shift;

    if ( exists $self->{value}->{$key} ) {

        # print "key $key => $self->{value}->{$key} \n";
        return $self->{value}->{$key};
    }
    else {
        die("$key does not exist!");
    }
}

sub initialize {
    my $self = shift;

    $self->{conf} = Config::General->new(
        -ConfigFile       => $self->{file},
        -ExtendedAccess   => 1,
        -ApacheCompatible => 1
    );

    my %data = $self->{conf}->getall();

    print "data: ", Dumper(%data), "\n";

    my @keys = keys %data;
    for my $key (@keys) {
        print "key = $key, val =" . $data{$key} . "\n";
        if ( $key eq 'Camera' ) {
            my $cam;
            foreach $cam ( keys $data{$key} ) {
                my $new_cam = new MotionProxy::Camera($cam,$data{$key}->{$cam});
                #print "new_cam . "\n";
            }
            #print "cam: ", Dumper($new_cam), "\n";
            next;
        }
        if ( $key eq 'Queue' ) {
            my $queue;
            foreach $queue ( keys $data{$key} ) {
                my $new_queue = new MotionProxy::Queue($queue,$data{$key}->{$queue});
                print "new_queue: " , Dumper($new_queue), "\n";
            }
            print "queue: ", Dumper($data{$key}), "\n";
            next;
        }
        # else, top-level value
        $self->{value}->{$key} = $data{$key};
    }
    $self->{data} = \%data;
    return $self;
}

# print __FILE__ . ": @INC: \n";

1;

__END__

