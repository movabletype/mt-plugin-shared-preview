use strict;
use warnings;

use Test::More;

# FIXME

use lib qw( lib extlib plugins/SharedPreview/lib );

use_ok 'MT::App::SharedPreview';
use_ok 'SharedPreview::Auth';
use_ok 'MT::Preview';
use_ok 'SharedPreview::CMS::ContentData';
use_ok 'SharedPreview::CMS::Entry';
use_ok 'SharedPreview::CMS::SharedPreview';
use_ok 'SharedPreview::L10N';
use_ok 'SharedPreview::L10N::en_us';
use_ok 'SharedPreview::L10N::ja';

done_testing;

