BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Test::More tests => 6 + (4 * 24);
use strict;
BEGIN { eval {require warnings} or do {$INC{'warnings.pm'} = ''} } #BEGIN
use warnings;

BEGIN {use_ok( 'load','ondemand' )}

can_ok( 'load',qw(
 AUTOLOAD
 import
) );

my $module = "Foo";
my $filepm = "$module.pm";
my $always = "always $load::VERSION\n";
my $ondemand = "ondemand $load::VERSION\n";
my $INC = qq{@{[map {"-I$_"} @INC]}};

ok( (open OUT, ">$filepm"), "Create dummy module for testing" );

ok( (print OUT <<EOD),"Write the dummy module" );
package $module;
use load;
\$VERSION = '$load::VERSION';
sub always { print "always \$VERSION\n" }
__END__
sub ondemand { print "ondemand \$VERSION\n" }
EOD

ok( (close OUT),"Close the dummy module" );

foreach my $action ('',qw(-Mload=now -Mload=ondemand -Mload=dontscan)) {
    ok( (open( IN,
     "$^X -I. $INC $action -MFoo -e 'print ${module}::always()' |" )),
      "Open check always on $action" );
    is( scalar <IN>,$always,"Check always with $action" );
    ok( (close IN),"Close check always with $action" );

    ok( (open( IN,
     "$^X -I. $INC $action -MFoo -e 'print ${module}::ondemand()' |" )),
      "Open check ondemand with $action" );
    is( scalar <IN>,$ondemand,"Check ondemand with $action" );
    ok( (close IN),"Close check ondemand with $action" );

    foreach (qw(always ondemand)) {
        ok( (open( IN,
         "$^X -I. $INC $action -MFoo -e 'print exists \$Foo::{$_}' |" )),
          "Open check exists $_ with $action" );
        is( scalar <IN>,'1',"Check exists $_ with $action" );
        ok( (close IN),"Close check exists $_ with $action" );

        ok( (open( IN,
         "$^X -I. $INC $action -MFoo -e 'print Foo->can($_)' |" )),
          "Open check Foo->can( $_ ) with $action" );
        ok( (<IN> =~ m#^CODE#),"Check Foo->can( $_ ) with $action" );
        ok( (close IN),"Close check Foo->can( $_ ) with $action" );
    }

    foreach ('exists $Foo::{bar}','Foo->can(bar)') {
        ok( (open( IN,
         "$^X -I. $INC $action -MFoo -e '$_' |" )),
          "Open check $_ with $action" );
        ok( !defined <IN>,"Check $_ with $action" );
        ok( (close IN),"Close check $_ bar with $action" );
    }
}

ok( (unlink $filepm),"Clean up dummy module" );
