#!/usr/bin/perl -w
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'load',
    VERSION_FROM    => 'lib/load.pm',                # finds $VERSION
    AUTHOR          => 'Jos Boumans (kane@cpan.org)',
);