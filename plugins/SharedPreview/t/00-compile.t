use strict;
use warnings;

use Test::More;

# FIXME

use lib qw( lib extlib plugins/SharedPreview/lib );

use_ok 'MT::App::Auth::SharedPreviewAuth';
use_ok 'MT::App::SharedPreview';
use_ok 'MT::Preview';
use_ok 'MT::Validators::PreviewValidator';
use_ok 'MT::Validators::SharedPreviewAuthValidator';
use_ok 'SharedPreview::CMS::ContentData';
use_ok 'SharedPreview::CMS::Entry';
use_ok 'SharedPreview::CMS::SharedPreviewBase';

done_testing;

