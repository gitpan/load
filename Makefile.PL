require 5.000;
use ExtUtils::MakeMaker;

WriteMakefile (
 NAME		=> "load",
 ($] < 5.005) ? () : (
 AUTHOR		=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
 ABSTRACT	=> 'load - control when subroutines will be loaded'),
 VERSION_FROM	=> 'lib/load.pm',
 PREREQ_PM	=> {
                   },
);
