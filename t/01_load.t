BEGIN { chdir 't' if -d 't' };

use strict;
use lib qw[../lib lib toload];
use Test::More tests => 6;

my $Class = 'load';

use_ok $Class;
eval "use $Class";

can_ok( $Class, qw[load] );

load( 'a.pl' );
is( $INC{'a.pl'},   'toload/a.pl',  q[Can load files] );

load( 'A' );
is( $INC{'A.pm'},   'toload/A.pm',  q[Can load files] );

load( 'c' );
is( $INC{'c.pm'},   'toload/c.pm',  q[Can load ambiguous modules] );

load( 'd' );
is( $INC{'d'},      'toload/d',     q[Can load ambiguous files] );