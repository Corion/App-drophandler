#!perl -w
use strict;
no warnings 'experimental';
use feature 'signatures';
use warnings 'experimental';
use Dancer;
use App::drophandler;

use Getopt::Long;
#use Config::IniFiles;

# Also support pjax?!

GetOptions(
    'c|config:s' => \my $configfile,
);

#$configfile ||= './drophandler.ini';

#reload_config( $configfile );

dance;