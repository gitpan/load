BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Test::More tests => 6 + (5*24) + (3*3) + (3*3) + (2*3);
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
sub empty {}
EOD
ok( (close OUT),"Close the dummy module" );

$ENV{'LOAD_NOW'} = 0;
$ENV{'LOAD_TRACE'} = 0;

foreach (qw(env -Mload=now -Mload=ondemand -Mload=dontscan),'') {
    my $action = $_;
    if ($action eq 'env') {
        $ENV{'LOAD_NOW'} = 1;
        $action = '';
    }

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

$ENV{'LOAD_NOW'} = 0;
$ENV{'LOAD_TRACE'} = 1;

foreach ('',qw(-Mload=ondemand -Mload=dontscan)) {
    my $action = $_;
    ok( (open( IN, "$^X -I. $INC $action -MFoo -e '' 2>&1 |" )),
     "Open trace store $action" );
    like( join( '',<IN> ),
    qr/load: store Foo::ondemand, line \d+ \(offset \d+, \d+ bytes\)
load: store Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
$/,"Check trace ondemand $action" );
    ok( (close IN),"Close trace ondemand $action" );
}

foreach ('',qw(-Mload=ondemand -Mload=dontscan)) {
    my $action = $_;
    ok( (open( IN, "$^X -I. $INC $action -MFoo -e 'Foo::empty()' 2>&1 |" )),
     "Open trace store load $action" );
    like( join( '',<IN> ),
    qr/load: store Foo::ondemand, line \d+ \(offset \d+, \d+ bytes\)
load: store Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
load: ondemand Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
$/,"Check trace ondemand $action" );
    ok( (close IN),"Close trace ondemand $action" );
}

foreach (qw(-Mload=now),'env') {
    my $action = $_;
    if ($action eq 'env') {
        $ENV{'LOAD_NOW'} = 1;
        $action = '';
    }

    ok( (open( IN, "$^X -I. $INC $action -MFoo -e 'Foo::empty()' 2>&1 |" )),
     "Open trace store load $action" );
    like( join( '',<IN> ),
    qr/load: now Foo, line \d+ \(offset \d+, onwards\)
$/,"Check trace now $action" );
    ok( (close IN),"Close trace ondemand $action" );
}

ok( (unlink $filepm),"Clean up dummy module" );
