BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

my @extra;
BEGIN {
    eval { require ifdef };
    if ($@) {
        @extra = ('');
    } else {
        shift @INC;
        $ENV{IFDEF_DIFF} = 0;
        @extra = ('','-Mifdef=FOO ','-Mifdef=DEBUGGING ' );
    }
} #BEGIN

use Test::More tests =>
 5 +
 (@extra * 2 * (
  (5 * (12 + 2 * 6 + 2 * 3)) +
  (3*3) +
  (3*3) +
  (2*3) +
  (3*3) +
  (3*3) +
  (2*3)
 )) +
 1;

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
my $always = "always $load::VERSION";
my $ondemand = "ondemand $load::VERSION";
my $debugging_only = "debugging_only $load::VERSION";
my $ondemand_debugging_only= "ondemand_debugging_only $load::VERSION";
my $bs = ($^O =~ m#MSWin#) ? '' : '\\' ; # Argh, Windows!
my $INC = qq{@{[map {"-I$_"} @INC]}};

ok( (open OUT, ">$filepm"), "Create dummy module for testing" );
ok( (print OUT <<EOD),"Write the dummy module" );
package $module;
use load;
\$VERSION = '$load::VERSION';
sub always {
    print "always \$VERSION";
}

=begin DEBUGGING

sub debugging_only {
    print "debugging_only \$VERSION";
}

=cut

1;

__END__
sub ondemand {
    print "ondemand \$VERSION";
}
sub empty {
    undef;
}

=begin DEBUGGING

sub ondemand_debugging_only {
    print "ondemand_debugging_only \$VERSION";
}

=cut
EOD
ok( (close OUT),"Close the dummy module" );

foreach my $extra (@extra) {
    my $debugging = $extra =~ m#DEBUGGING#;
    foreach ('','-T ') {
        $INC = "$_$INC";

        $ENV{'LOAD_NOW'} = 0;
        $ENV{'LOAD_TRACE'} = 0;

        foreach (qw(env -Mload=now -Mload=ondemand -Mload=dontscan),'') {
            my $action = $_;
            if ($action eq 'env') {
                $ENV{'LOAD_NOW'} = 1;
                $action = '';
            }

            ok( (open( IN,
             qq{$^X -I. $INC $extra$action -MFoo -e "${module}::always()" |} )),
              "Open check always on $action" );
            is( scalar <IN>,$always,"Check always with $action" );
            ok( (close IN),"Close check always with $action" );

            ok( (open( IN,
             qq{$^X -I. $INC $extra$action -MFoo -e "${module}::ondemand()" |} )),
              "Open check ondemand with $action" );
            is( scalar <IN>,$ondemand,"Check ondemand with $action" ) or die;
            ok( (close IN),"Close check ondemand with $action" );

            ok( (open( IN,
             qq{$^X -I. $INC $extra$action -MFoo -e "${module}::debugging_only()" 2>stderr |} )),
              "Open check debugging_only on $action" );
            if ($debugging) {
                is( scalar <IN>,$debugging_only,
                 "Check debugging_only with $_ and $action" );
                ok( (close IN),
                 "Close check debugging_only $_ and with $action" );
            } else {
                ok( !defined <IN>,"Check $_ with $action" );
                ok( 1 ,"Extra ok for unopened pipe for $_ with $action" );
            }

            ok( (open( IN,
             qq{$^X -I. $INC $extra$action -MFoo -e "${module}::ondemand_debugging_only()" 2>stderr |} )),
              "Open check ondemand_debugging_only with $action" );
            if ($debugging) {
                is( scalar <IN>,$ondemand_debugging_only,
                 "Check ondemand_debugging_only with $action" );
                ok( (close IN),
                 "Close check ondemand_debugging_only with $action" );
            } else {
                ok( !defined <IN>,"Check $_ with $action" );
                ok( 1 ,"Extra ok for unopened pipe for $_ with $action" );
            }

            foreach (qw(always ondemand)) {
                ok( (open( IN,
                 qq{$^X -I. $INC $extra$action -MFoo -e "print exists $bs\$Foo::{$_}"|})),
                  "Open check exists $_ with $action" );
                is( scalar <IN>,'1',"Check exists $_ with $action" );
                ok( (close IN),"Close check exists $_ with $action" );

                ok( (open( IN,
                 qq{$^X -I. $INC $extra$action -MFoo -e "print Foo->can($_)" |} )),
                  "Open check Foo->can( $_ ) with $action" );
                ok( (<IN> =~ m#^CODE#),"Check Foo->can( $_ ) with $action" );
                ok( (close IN),"Close check Foo->can( $_ ) with $action" );
            }

            foreach ("exists $bs\$Foo::{bar}","Foo->can(bar)") {
                ok( (open( IN,
                 qq{$^X -I. $INC $extra$action -MFoo -e "$_" |} )),
                  "Open check $_ with $action" );
                ok( !defined <IN>,"Check $_ with $action" );
                ok( (close IN),"Close check $_ bar with $action" );
            }
        }

        $ENV{'LOAD_NOW'} = 0;
        $ENV{'LOAD_TRACE'} = 1;

        foreach ('',qw(-Mload=ondemand -Mload=dontscan)) {
            my $action = $_;
            ok( (open( IN, qq{$^X -I. $INC $extra$action -MFoo -e "" 2>&1 |} )),
             "Open trace store $action" );
            my $ondemand = $debugging ? <<'EOD' : '';
load: store Foo::ondemand_debugging_only, line \d+ \(offset \d+, \d+ bytes\)
EOD
            like( join( '',<IN> ),
             qr/load: store Foo::ondemand, line \d+ \(offset \d+, \d+ bytes\)
load: store Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
$ondemand$/,"Check trace ondemand $action" );
            ok( (close IN),"Close trace ondemand $action" );
        }

        foreach ('',qw(-Mload=ondemand -Mload=dontscan)) {
            my $action = $_;
            my $ondemand = $debugging ? <<'EOD' : '';
load: store Foo::ondemand_debugging_only, line \d+ \(offset \d+, \d+ bytes\)
EOD
            ok( (open( IN, qq{$^X -I. $INC $extra$action -MFoo -e "Foo::empty()" 2>&1|})),
             "Open trace store load $action" );
            like( join( '',<IN> ),
             qr/load: store Foo::ondemand, line \d+ \(offset \d+, \d+ bytes\)
load: store Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
${ondemand}load: ondemand Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
$/,"Check trace ondemand $action" );
            ok( (close IN),"Close trace ondemand $action: $!" );
        }

        foreach (qw(-Mload=now),'env') {
            my $action = $_;
            if ($action eq 'env') {
                $ENV{'LOAD_NOW'} = 1;
                $action = '';
            }

            ok( (open( IN, qq{$^X -I. $INC $extra$action -MFoo -e "Foo::empty()" 2>&1|})),
             "Open trace store load $action" );
            like( join( '',<IN> ),
             qr/load: now Foo, line \d+ \(offset \d+, onwards\)
$/,"Check trace now $action" );
            ok( (close IN),"Close trace ondemand $action" );
        }

        $ENV{'LOAD_NOW'} = 0;
        $ENV{'LOAD_TRACE'} = 1;

        SKIP: {
            require Config;
            skip( "No threads support available", (3*3)+(3*3)+(2*3) )
             unless $Config::Config{useithreads};

            my $ondemand = $debugging ? <<'EOD' : '';
load \[0\]: store Foo::ondemand_debugging_only, line \d+ \(offset \d+, \d+ bytes\)
EOD

            foreach ('',qw(-Mload=ondemand -Mload=dontscan)) {
                my $action = $_;
                ok( (open( IN, qq{$^X -I. $INC -Mthreads $extra$action -MFoo -e "" 2>&1 |} )),
                 "Open trace store $action with threads" );
                like( join( '',<IN> ),
                 qr/load \[0\]: store Foo::ondemand, line \d+ \(offset \d+, \d+ bytes\)
load \[0\]: store Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
$ondemand$/,"Check trace ondemand $action with threads" );
                ok( (close IN),"Close trace ondemand $action with threads" );
            }

            foreach ('',qw(-Mload=ondemand -Mload=dontscan)) {
                my $action = $_;
                ok((open( IN, qq{$^X -I. $INC -Mthreads $extra$action -MFoo -e "Foo::empty()" 2>&1 |})),
                 "Open trace store load $action with threads" );
                like( join( '',<IN> ),
                 qr/load \[0\]: store Foo::ondemand, line \d+ \(offset \d+, \d+ bytes\)
load \[0\]: store Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
${ondemand}load \[0\]: ondemand Foo::empty, line \d+ \(offset \d+, \d+ bytes\)
$/,"Check trace ondemand $action with threads" );
                ok( (close IN),"Close trace ondemand $action with threads" );
            }

            foreach (qw(-Mload=now),'env') {
                my $action = $_;
                if ($action eq 'env') {
                    $ENV{'LOAD_NOW'} = 1;
                    $action = '';
                }

                ok( (open(IN, qq{$^X -I. $INC -Mthreads $extra$action -MFoo -e "Foo::empty()" 2>&1 |})),
                 "Open trace store load $action with threads" );
                like( join( '',<IN> ),
                 qr/load \[0\]: now Foo, line \d+ \(offset \d+, onwards\)
$/,"Check trace now $action with threads" );
                ok( (close IN),"Close trace ondemand $action with threads" );
            }
        }
    }
}

ok( (unlink $filepm,'stderr'),"Clean up dummy module and stderr file" );
1 while unlink $filepm,'stderr'; # multiversioned filesystems