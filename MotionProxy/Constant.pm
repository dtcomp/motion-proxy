package MotionProxy::Constant;

use constant LOGNAME      =>'motion-proxy';
use constant CONFIGPATH   =>"/etc/" . LOGNAME;
use constant CONFIGFILE   =>LOGNAME . ".conf";
use constant LASTFILENAME =>'last.jpg';
use constant CAMPATH      =>'/snapshot.jpg';
use constant CONFIG       => CONFIGPATH . '/' . CONFIGFILE;

# print __FILE__ . ": @INC: \n";
1;



__END__

