BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Test::More tests => 2;
use strict;
use warnings;

BEGIN {use_ok( 'load','ondemand' )}

can_ok( 'load',qw(
 AUTOLOAD
 import
) );
