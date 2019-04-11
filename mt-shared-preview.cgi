#!/usr/bin/perl
use strict;
use warnings;

use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : 'lib';
use lib $ENV{MT_HOME}
    ? "$ENV{MT_HOME}/plugins/SharedPreview/lib"
    : 'plugins/SharedPreview/lib';
use MT::Bootstrap App => 'MT::App::SharedPreview';

