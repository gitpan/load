package load;

$VERSION = 0.01;

use strict;
use File::Spec ();

sub import {
    my $who = _who();

    {   no strict 'refs';
        *{"${who}::load"} = *load;
    }
}

sub load (*)  {
    my $mod = shift or return;
    my $who = _who();

    if( _is_file( $mod ) ) {
        require $mod;
    } else {
        LOAD: {
            my $err;
            for my $flag ( qw[1 0] ) {
                my $file = _to_file( $mod, $flag);

                eval { require $file };
                $@ ? $err .= $@ : last LOAD;
            }
            die $err if $err;
        }
    }
}

sub _is_file {
    local $_ = shift;
    return  /^\./               ? 1 :
            /[^\w:]/            ? 1 :
            undef
}

sub _to_file{
    local $_    = shift;
    my $pm      = shift || '';

    my $file = File::Spec->catfile( split /::/ );
    $file   .= '.pm' if $pm;

    return $file;
}

sub _who { (caller(1))[0] }

1;

__END__

=pod

=head1 NAME

load - runtime require of both modules and files

=head1 VERSION

This document describes version 0.01 of load, released Nov 24, 2002.

=head1 SYNOPSIS

	use load;

        my $module = 'Data:Dumper';

	load Data::Dumper;      # loads that module
        load 'Data::Dumper';    # ditto
        load $module            # tritto

        my $script = 'some/script.pl'
        load $script;
        load 'some/script.pl';	# use quotes because of punctuations


        load thing;             # try 'thing' first, then 'thing.pm'

=head1 DESCRIPTION

C<load> eliminates the need to know whether you are trying to require
either a file or a module.

If you consult C<perldoc -f require> you will see that C<require> will
behave differently when given a bareword or a string.

In the case of a string, C<require> assumes you are wanting to load a
file. But in the case of a bareword, it assumes you mean a module.

This gives nasty overhead when you are trying to dynamically require
modules at runtime, since you will need to change the module notation
(C<Acme::Comment>) to a file notation fitting the particular platform
you are on.

C<load> elimates the need for this overhead and will just DWYM.

=head1 Rules

C<load> has the following rules to decide what it thinks you want:

=over 4

=item *

If the argument has any characters in it other than those matching
C<\w> or C<:>, it must be a file

=item *

If the argument matches only C<[\w:]>, it must be a module

=item *

If the argument matches only C<\w>, it could either be a module or a
file. We will try to find C<file> first in C<@INC> and if that fails,
we will try to find C<file.pm> in @INC.
If both fail, we die with the respective error messages.

=back

=head1 NOTE

There is one very important distinction between C<load> and C<require>:

C<load> does not allow you to use the indirect object syntax, whereas
C<require> does:

    package MyPackage;
    sub new { ... }

    require Foo;

    my $obj = new Foo(@args);

will call

    my $obj = Foo->new(@args);

whereas

    package MyPackage;
    sub new { ... }

    load Foo;
    my $obj = new Foo(@args);

will call

    my $obj = MyPackage::new(@args);


=head1 TODO

=over 4

=item *

Allow for C<import()> arguments and version checks

=item *

Allow a compile time equivalent of load (perhaps C<use load LWP>)

=back

=head1 AUTHOR

This module by
Jos Boumans E<lt>kane@cpan.orgE<gt>.

=head1 COPYRIGHT

This module is
copyright (c) 2002 Jos Boumans E<lt>kane@cpan.orgE<gt>.
All rights reserved.

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=cut                               