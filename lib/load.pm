package load;

# Make sure we have version info for this module
# Make sure we do everything by the book from now on

$VERSION  = '0.02';
use strict;

# The hash in which we keep where which package has its subroutines

use vars qw(%AUTOLOAD);

# Flag indicating whether everything should be loaded immediately

my $now = 0;

# Allow for dirty tricks
# Save current code ref of UNIVERSAL::can
# Replace it with something that will also check on demand subroutines

{
 no strict 'refs';
 my $can = \&UNIVERSAL::can;
 *UNIVERSAL::can = sub { &{$can}( @_ ) || (ref( $_[0] ) ? undef : _can( @_ )) };
}

# Satisfy -require-

1;

#---------------------------------------------------------------------------

# standard Perl features

#---------------------------------------------------------------------------
#  IN: class (ignored)

sub import {

# Lose the class
# Obtain the module name

    shift;
    my $module = caller();

# If there were any parameters specified
#  Initialize the context flag
#  Initialize the autoload export flag
#  Initialize the scan flag
#  Create local copy of load now flag

    if (@_) {
        my $inmain = $module eq 'main';
        my $autoload = !$inmain;
        my $scan = 1;
        my $thisnow = $now;

#  For all of the parameters specified
#   Fetch action to be done, die if unknown keyword and execute action

        foreach (@_) {
            my $todo = {

             autoload => sub {
              die "Can not autoload in main namespace" if $inmain;
              $autoload = 1;
             },

             inherit => sub {
              die "Can not inherit in main namespace" if $inmain;
              $autoload = 0;
             },

             now => sub {
              ($inmain ? $now = $thisnow : $thisnow) = $scan = 1;
             },

             dontscan => sub {
              ($inmain ? $now = $thisnow : $thisnow) = $scan = 0;
             },

             ondemand => sub {
              ($inmain ? $now = $thisnow : $thisnow) = 0;
              $scan = 1;
             },

            }->{$_} or die "Don't know how to handle $_";
            &{$todo};
        }

#   If we're in a module
#    Scan the file, using local flag setting, if we should scan
#    Export AUTOLOAD if so requested

        unless ($inmain) {
            _scan( $module,$thisnow ) if $scan;
            {no strict 'refs';*{$module.'::AUTOLOAD'}=\&AUTOLOAD if $autoload};
        }

# Elseif called from a script
#  Die indicating that doesn't make any sense

    } elsif ($module eq 'main') {
       die "Does not make sense to just 'use load' from your script";

# Else (no parameters specified)
#  Scan the source
#  And export the AUTOLOAD subroutine

    } else {
        _scan( $module );
        {no strict 'refs'; *{$module.'::AUTOLOAD'} = \&AUTOLOAD};
    }
} #import

#---------------------------------------------------------------------------

sub AUTOLOAD {

# Obtain the module and subroutine name
# If the subroutine can be loaded
# Elsif we requested DESTROY (and we don't know about it)
#  Just return (gotoing it when it doesn't exist, will just bring us back here)
# Go execute the routine (whether it exists or not)

    my ($module,$sub) = ($1,$2) if $load::AUTOLOAD =~ m#^(.*)::(.*?)$#;
    if (_can( $module,$sub )) {
    } elsif ($sub eq 'DESTROY') {
        return;
    }
    goto &{$module.'::'.$sub};
} #AUTOLOAD

#---------------------------------------------------------------------------

# internal subroutines

#---------------------------------------------------------------------------
#  IN: 1 module to scan (AAA::BBB)
#      2 optional: flag to load everything now

sub _scan {

# Obtain the module
# Obtain the load now flag
# Make sure we won't clobber sensitive system vars

    my $module = shift;
    my $loadnow = defined($_[0]) ? shift : $now;
    local( $_,$!,$@ );

# Obtain the filename, die if failed
# Attempt to open the file for reading, die if failed
# Remove the .pm from the module name, we don't need it anymore

    my $file = _filename( $module )
     or die "Could not find file for '$module'";
    open( my $handle,"<$file" )
     or die "Could not open file '$file' for '$module': $!";

# Initialize line number
# Initialize the within pod flag
# Initialize the package name we're working for

    my $line = 0;
    my $pod = 0;
    my $package = '';

# While there are lines to be read
#  Increment line number
#  Reloop if a pod line, setting flag right on the fly
#  Reloop now if in pod or a comment line
#  Outloop now if we found the good stuff
#  Reloop if there is no package specification
#  Die now if we found a package declaration before
#  Set the package (it's the first one)

    while (<$handle>) {
        $line++;
        $pod = !m#^=cut#, next if m#^=\w#;
        next if $pod or m#^\s*\##;
        last if m#^__END__#;
        next unless m#^package\s+([\w:]+)\s*;#;
        die "Found package '$1' after '$package'" if $package;
        $package = $1;
    }

# Die now if there is no package
# Die now if it is not the right package

    die "Could not find package name" unless $package;
    die "Found package $package inside '$file'" if $package ne $module;

# Save the line after which __END__ sits
# Save the offset of the first line after __END__

    my $endline = $line+1;
    my $endstart = tell( $handle );

# If we're supposed to load now
#  Initialize the source to be evaluated
#  Enable slurp mode
#  Read the rest of the file

    if ($loadnow) {
        my $source = <<EOD;
package $module
#line $endline "$file (loaded on demand from offset $endstart)"
EOD
	local( $/ );
        $source .= <$handle>;

#  Make the stuff known to the system
#  Die now if failed

        {no strict; eval $source};
        die "Error evaluating source: $@" if $@;

# Else (we're to load everything ondemand)
#  Initialize the start position
#  Initialize the sub name being handled
#  Initialize the line number of the sub being handled

    } else {
        my $start;
        my $sub = '';
        my $subline;

#  While there are lines to be read
#   Increment line number
#   Reloop if a pod line, setting flag right on the fly
#   Reloop now if in pod or a comment line
#   Outloop now if we hit the actual documentation

        while (<$handle>) {
            $line++;
            $pod = !m#^=cut#, next if m#^=\w#;
            next if $pod or m#^\s*\##;
            last if m#^__END__#;

#   Die now if there is a package found (while we have one already)
#   Reloop if we didn't reach a new sub

            die "Only one package per file: found '$1' after '$package'"
             if m#^package\s+([\w:]+)\s*;#;
            next unless m#^sub\s+([\w:]+)#;

#   Remember the location where this sub starts
#   Store the information of the previous sub if there was one
#   Set the name of this sub
#   Die now if it is fully qualified sub
#   Remember where at which line number this sub starts
#   Remember where at which offset this sub starts
#  Store the information of the last sub if there was one

            my $seek = tell($handle) - length();
            _store( $module,$sub,$subline,$start,$seek-$start ) if $sub;
            $sub = $1;
            die "Cannot handle fully qualified subroutine '$sub'\n"
             if $sub =~ m#::#;
	    $subline = $line;
            $start = $seek;
        }
        _store(
	  $module,
	  $sub,
          $subline,
	  $start,
	  (defined() ? tell($handle) - length() : -s $handle) - $start
	) if $sub;
    }

# Mark this module as scanned
# Close the handle, we're done

    $AUTOLOAD{$module} = undef;
    close( $handle );
} #_scan

#---------------------------------------------------------------------------
#  IN: 1 module name (AAA::BBB)
# OUT: 1 filename (/..../AAA/BBB.pm) or undef if not known

sub _filename {

# Obtain the key
# Convert the ::'s to /'s
# Return whatever is available for that

    my $key = shift;
    $key =~ s#::#/#g;
    $INC{"$key.pm"};
} #_filename

#---------------------------------------------------------------------------
#  IN: 1 module name
#      2 subroutine name (not fully qualified)
#      3 line number where sub starts
#      4 offset where sub starts
#      5 number of bytes to read

sub _store {

# Make sure there is a stub
# Store the data

    eval "package $_[0]; sub $_[1];";
    $AUTOLOAD{$_[0],$_[1]} = pack( 'L3',$_[2],$_[3],$_[4] )
} #_store

#---------------------------------------------------------------------------
#  IN: 1 module name
#      2 subroutine name (not fully qualified)
# OUT: 1 line number where sub starts
#      2 offset where sub starts
#      3 number of bytes to read

sub _fetch { unpack( 'L3',$AUTOLOAD{$_[0],$_[1]} ) } #_fetch

#---------------------------------------------------------------------------
#  IN: 1 module name
#      2 subroutine name (not fully qualified)

sub _delete { delete( $AUTOLOAD{$_[0],$_[1]} ) } #_delete

#---------------------------------------------------------------------------
#  IN: 1 module to load subroutine from
#      2 subroutine to load
# OUT: 1 reference to subroutine (if exists and loaded, else undef)

sub _can {

# Obtain the module and subroutine name
# Return now if trying for application (the real UNIVERSAL::can should do that)
# Scan the file if it wasn't done yet
# Obtain coordinates of subroutine
# Return now if not known

    my ($module,$sub) = @_;
    return if $module eq 'main';
    _scan( $module ) unless exists( $AUTOLOAD{$module} );
    my ($subline,$start,$length) = _fetch( $module,$sub );
    return unless $start;

# Make sure we don't clobber sensitive system variables
# Obtain the filename or die
# Open the file or die
# Seek to the right place or die

    local( $!,$@ );
    my $file = _filename( $module )
     or die "Could not find file for '$module.pm'";
    open( my $handle,"<$file" )
     or die "Could not open file '$file' for '$module.pm': $!";
    seek( $handle,$start,0 )
     or die "Could not seek to $start for $module\::$sub";

# Initialize the source to be evalled
# Add the source of the subroutine to it and get number of bytes read
# Die now if we didn't get what we expected

    my $source = <<EOD;
package $module;
#line $subline "$file (loaded on demand from offset $start for $length bytes)
EOD
    my $read = read( $handle,$source,$length,length($source) );
    die "Error reading source: only read $read bytes instead of $length"
     if $read != $length;

# Make the stuff known to the system
# Die now if failed
# Remove the info of this sub (it's not needed anymore)

    {no strict; eval $source};
    die "load: $@" if $@;
    _delete( $module,$sub );

# Allow for variable references
# Return the code reference to what we just loaded

    no strict 'refs';
    return \&{$module.'::'.$sub};
} #_can

#---------------------------------------------------------------------------

__END__

=head1 NAME

load - control when subroutines will be loaded

=head1 SYNOPSIS

  use load;            # default, same as 'autoload'

  use load 'autoload'; # export AUTOLOAD handler to this namespace

  use load 'ondemand'; # load subroutines after __END__ when requested, default

  use load 'now';      # load subroutines after __END__ now

  use load ();         # same as qw(dontscan inherit)

  use load 'dontscan'; # don't scan module until it is really needed

  use load 'inherit';  # do NOT export AUTOLOAD handler to this namespace

=head1 DESCRIPTION

The "load" pragma allows a module developer to give the application developer
more options with regards to optimize for memory or CPU usage.  The "load"
pragma gives more control on the moment when subroutines are loaded and start
taking up memory.  This allows the application developer to optimize for CPU
usage (by loading all of a module at compile time and thus reducing the
amount of CPU used during the execution of an application).  Or allow the
application developer to optimize for memory usage, by loading subroutines
only when they are actually needed, thereby however increasing the amount of
CPU needed during execution.

The "load" pragma combines the best of both worlds from L<AutoLoader> and
L<SelfLoader>.  And adds some more features.

In a situation where you want to use as little memory as possible, the "load"
pragma (in the context of a module) is a drop-in replacement for L<AutoLoader>.
But for situations where you want to have a module load everything it could
ever possibly need (e.g. when starting a mod_perl server in pre-fork mode), the
"load" pragma can be used (in the context of an application) to have all
subroutines of a module loaded without having to make any change to the source
of the module in question.

So the typical use inside a module is to have:

 package Your::Module;
 use load;

in the source.  And to place all subroutines that you want to be loadable on
demand after the (first) __END__.

If an application developer decides that all subroutines should be loaded
at compile time, (s)he can say in the application:

 use load 'now';
 use Your::Module;

This will cause the subroutines of Your::Module to all be loaded at compile
time.

=head1 MODES OF OPERATION

There are basically two places where you can call the "load" pragma:

=head2 inside a module

When you call the "load" pragma inside a module, you're basically enabling that
module for having an external control when certain subroutines will be loaded.
As with AutoLoader, any subroutines that should be loaded on demand, should be
located B<after> an __END__ line.

If no parameters are specified with the C<use load>, then the "autoload"
parameter is assumed.  Whether the module's subroutines are loaded at compile
time or on demand, is determined by the calling application.  If the
application doesn't specify anything specific, the "ondemand" keyword will
also be assumed.

=head2 inside an application

When you call the "load" pragma inside an application, you're basically
specifying when subroutines will be loaded by "load" enhanced modules.  As an
application developer, you can basically use two keywords: "ondemand" and
"now".

If an application does not call the "load" pragma, the "ondemand" keyword will
be assumed.  With "ondemand", subroutines will only be loaded when they are
actually executed.  This saves memory at the expense of extra CPU the first
time the subroutine is called.

The "now" keyword indicates that all subroutines of all modules that are
enhanced with the "load" pragma, will be loaded at compile time (thus using
more memory, but B<not> having an extra CPU overhead the first time the
subroutine is executed).

=head1 KEYWORDS

The following keywords are recognized with the C<use> command:

=head2 ondemand

The "ondemand" keyword indicates that subroutines, of modules that are enhanced
with the "load" pragma, will only be loaded when they are actually called.

If the "ondemand" keyword is used in the context of an application, all
modules that are subsequently C<use>d, will be forced to load subroutines
only when they are actually called (unless the module itself forces a specific
setting).

If the "ondemand" keyword is used in the context of a module, it indicates
that the subroutines of that module, should B<always> be loaded when they are
actually needed.  Since this takes away the choice from the application
developer, the use of the "ondemand" keyword in module context is not
encouraged.  See also the L<now> and L<dontscan> keywords.

=head2 now

The "now" keyword indicates that subroutines, of modules that are enhanced
with the "load" pragma, will be loaded at compile time.

If the "now" keyword is used in the context of an application, all modules
that are subsequently C<use>d, will be forced to load all subroutines at
compile time (unless the module forces a specific setting itself).

If the "now" keyword is used in the context of a module, it indicates that the
subroutines of that module, should B<always> be loaded at compile time.  Since
this takes away the choice from the application developer, the use of the
"now" keyword in module context is not encouraged.  See also the L<ondemand>
keyword.

=head2 dontscan

The "dontscan" keyword only makes sense when used in the context of a module.
Normally, when a module that is enhanced with the "load" pragma is compiled,
the source after the __END__ is scanned for the locations of the subroutines.
This makes the compiling of modules a little slower, but allows for a faster
(initial) lookup of (yet) unloaded subroutines during execution.

If the "dontscan" keyword is specified, this scanning of the source is
skipped at compile time.  However, as soon as an attempt is made to ececute
a subroutine from this module, then first the scanning of the source is
performed, before the subroutine in question is loaded.

So, you should use the "dontscan" keyword if you are reasonably sure that you
will only need subroutines from the module in special cases.  In all other
cases it will make more sense to have the source scanned at compile time.

The "dontscan" keyword will be ignored if an application developer forces
subroutines to be loaded at compile time with the L<now> keyword.

=head2 autoload

The "autoload" keyword only makes sense when used in the context of a module.
It indicates that a generic AUTOLOAD subroutine will be exported to the
module's namespace.  It is selected by default if you use the "load" pragma
without parameters in the source of a module.  See also the L<inherit> keyword
to B<not> export the generic AUTOLOAD subroutine.

=head2 inherit

The "inherit" keyword only makes sense when used in the context of a module.
It indicates that B<no> AUTOLOAD subroutine will be exported to the module's
namespace.  This can e.g. be used when you need to have your own AUTOLOAD
routine.  That AUTOLOAD routine should then contain:

 $load::AUTOLOAD = $sub;
 goto &load::AUTOLOAD;

to access the "load" pragma functionality.  Another case to use the "inherit"
keyword would be in a sub-class of a module which also is "load" enhanced.
In that case, the inheritance will cause the AUTOLOAD subroutine of the base
class to be used, thereby accessing the "load" pragma automagically (and hence
the naming of the keyword of course).  See also the L<autoload> keyword to
have the module use the generic AUTOLOAD subroutine.

=head1 DIFFERENCES WITH SIMILAR MODULES

There are a number of (core) modules that more or less do the same thing as
the "load" pragma.

=head2 AutoSplit / AutoLoader

The "load" pragma is very similar to the AutoSplit / AutoLoader combination.
The main difference is that the splitting takes place when the "load" import
is called in a module and that there are no external files created.  Instead,
just the offsets and lengths are recorded in a hash (when "ondemand" is active)
or all the source after __END__ is eval'led (when "now" is active).

From a module developer point of view, the advantage is that you do not need to
install a module before you can test it.  From an application developer point
of view, you have the flexibility of having everything loaded now or later (on
demand).

From a memory usage point of view, the "load" offset/length hash takes up more
memory than the equivalent AutoLoader setup.  On the other hand, accessing the
source of a subroutine may generally be faster because the file is more likely
to reside in the operating system's buffers already.

As an extra feature, the "load" pragma allows an application to force all
subroutines to be loaded at compile time, which is not possible with AutoLoader.

=head2 SelfLoader

The "load" pragma also has some functionality in common with the SelfLoader
module.  But it gives more granularity: with SelfLoader, all subroutines that
are not loaded directly, will be loaded if B<any> not yet loaded subroutine is
requested.  It also adds complexities if your module needs to use the <DATA>
handle.  So the "load" pragma gives more flexibility and fewer development
complexities.  And of course, an application can force all subroutines to be
loaded at compile time when needed with the "load" pragma.

=head1 UNIVERSAL::can

To ensure the functioning of the ->can class method and &UNIVERSAL::can,
the "load" pragma hijacks the standard UNIVERSAL::can routine so that it
can check whether the subroutine/method that you want to check for, actually
exists and have a code reference to it returned.  This has a side effect that
you the subroutine checked for, is loaded.  You can use this side effect to
load subroutines without calling them.

 Your::Module->can( 'loadthisnow' );

will load the subroutine "loadthisnow" of the Your::Module module without
actually calling it.

=head1 CAVEATS

Currently you may not have multiple packages in the same file, nor can you
have fully qualified subroutine names.

The parser that looks for package names and subroutines, is not very smart.
This is intentionally so, as making it smarter will make it a lot slower, but
probably still not smart enough.  Therefore, the C<package> and C<sub>'s
B<must> be at the start of a line.  And the name of the C<sub> B<must> be on
the same line as the C<sub>.

=head1 EXAMPLES

Some code examples.  Please note that these are just a part of an actual
situation.

=head2 base class

 package Your::Module;
 use load;

Exports the generic AUTOLOAD subroutine and adheres to whatever the application
developer specifies as mode of operation.

=head2 sub class

 package Your::Module::Adapted;
 @ISA = qw(Your::Module);
 use load ();

Does B<not> export the generic AUTOLOAD subroutine, but inherits it from its
base class.  Also implicitely specifies the "dontscan" keyword, causing the
source of the module to be scanned only when the first not yet loaded
subroutine is about to be executed.  If you only want to have the "inherit"
keyword functionality, then you must specify that explicitely:

 package Your::Module::Adapted;
 @ISA = qw(Your::Module);
 use load 'inherit';

=head2 custom AUTOLOAD

 package Your::Module;
 use load 'inherit';
 
 sub AUTOLOAD {
   if (some condition) {
     $load::AUTOLOAD = $Your::Module::AUTOLOAD;
     goto &load::AUTOLOAD;
   }
   # do your own stuff
 }

If you want to use your own AUTOLOAD subroutine, but still want to use the
functionality offered by the "load" pragma, you can use the above construct.

=head2 mod_perl prefork

 use load 'now';
 use Your::Module;

In pre-fork mod_perl applications (the default mod_perl applications before
mod_perl 2.0), it is advantageous to load all possible subroutines when the
Apache process is started.  This is because the operating system will share
memory using a process called "Copy On Write".  So even though it will take
more memory initially, that memory loss is easily evened out by the gains of
having everything shared.  Loading a not yet loaded subroutine in that
situation, will cause otherwise shared memory to become unshared.  Thereby
increasing the overall memory usage, because the amount that becomes unshared
is typically a lot more than the extra memory used by the subroutine (which
is caused by fragmentation of allocated memory).

=head2 threaded applications and mod_perl worker

 use Your::Module;

Threaded Perl applications, of which mod_perl applications using the "worker"
module are a special case, function best when subroutines are only loaded when
they are actually needed.  This is caused by the nature of the threading model
of Perl, in which all data-structures are B<copied> to each thread (essentially
forcing them to become unshared as far as the operating system is concerned).

Benchmarks have shown that the overhead of the extra CPU is easily offset by
the reduction of the amount of data that needs to be copied (and processed)
when a thread is created.

=head1 TODO

The coordinates of a subroutine in a module (start,number of bytes) are stored
in a hash in the load namespace.  Ideally, this information should be stored in
the stash of the module to which they apply.  Then the internals that check
for the existence of a subroutine, would see that the subroutine doesn't exist
(yet), but that there is an offset and length (and implicitely, a file from
%INC) from which the source could be read and evalled.

Loading all of the subroutines should maybe be handled inside the Perl parser,
having it skip __END__ when the global "now" flag is set.

Possibly we should use the <DATA> handle from a module if there is one, or dup
it and use that, rather than opening the file again.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2002 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<AutoLoader>, L<SelfLoader>.

=cut
