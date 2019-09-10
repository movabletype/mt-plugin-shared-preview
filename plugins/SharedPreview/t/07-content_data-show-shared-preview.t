use strict;
use warnings;
use FindBin;
use Cwd;

use lib Cwd::realpath("./t/lib");
use Test::More;
use MT::Test::Env;

our $test_env;

BEGIN {
    eval { require Test::MockModule }
        or plan skip_all => 'Test::MockModule is not installed';

    $test_env = MT::Test::Env->new(
        PluginPath => [ Cwd::realpath("$FindBin::Bin/../../../plugins") ], );

    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT;
use MT::Association;
use MT::Preview;
use MT::Test;
use MT::Test::Fixture;
use MT::Test::Permission;
use SharedPreview::Auth;
use SharedPreviewTest;
use MT::ContentStatus;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name = 'SharedPreviewNeedPasswordBlog1-' . time();
my $blog2_name = 'SharedPreviewNoPasswordBlog2-' . time();

my $super = 'super';

my $objs = MT::Test::Fixture->prepare(
    {   author => [ { 'name' => $super }, ],
        blog   => [ { name   => $blog1_name, }, { name => $blog2_name, }, ],

    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;
my $blog2 = MT->model('blog')->load( { name => $blog2_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;

my $content_type1 = MT::Test::Permission->make_content_type(
    name    => 'test content type 1',
    blog_id => $blog1->id,
);

my $content_type2 = MT::Test::Permission->make_content_type(
    name    => 'test content type 2',
    blog_id => $blog2->id,
);

my $content_field1 = MT::Test::Permission->make_content_field(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    name            => 'single line text 1',
    type            => 'single_line_text',
);

my $content_field2 = MT::Test::Permission->make_content_field(
    blog_id         => $content_type2->blog_id,
    content_type_id => $content_type2->id,
    name            => 'single line text 2',
    type            => 'single_line_text',
);

my $fields1 = [
    {   id        => $content_field1->id,
        order     => 1,
        type      => $content_field1->type,
        options   => { label => $content_field1->name },
        unique_id => $content_field1->unique_id,
    },
];

my $fields2 = [
    {   id        => $content_field2->id,
        order     => 1,
        type      => $content_field2->type,
        options   => { label => $content_field2->name },
        unique_id => $content_field2->unique_id,
    },
];

$content_type1->fields($fields1);
$content_type1->save or die;

$content_type2->fields($fields2);
$content_type2->save or die;

my $content_data1 = MT::Test::Permission->make_content_data(
    blog_id         => $blog1->id,
    content_type_id => $content_type1->id,
    status          => MT::ContentStatus::HOLD(),
    data            => { $content_field1->id => 'HOLD 1' },
    author_id       => $super_author->id,
);

my $content_data2 = MT::Test::Permission->make_content_data(
    blog_id         => $blog2->id,
    content_type_id => $content_type2->id,
    status          => MT::ContentStatus::HOLD(),
    data            => { $content_field2->id => 'HOLD 2' },
    author_id       => $super_author->id,
);

my $plugin_data = MT::Test::Permission->make_plugindata(
    plugin => 'SharedPreview',
    key    => 'configuration:blog:' . $blog1->id,
    data   => { 'sp_password[]' => [ 'test', 'test2' ] }
);

subtest 'show_shared_preview' => sub {
    subtest 'need to login' => sub {
        subtest 'no cookie' => sub {
            my ( $app, $spid ) = SharedPreviewTest::make_shared_preview(
                $super_author,      $blog1->id,
                $content_data1->id, $content_type1->id
            );

            my $output
                = SharedPreviewTest::request_show_shared_preview($spid);
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_redirect_login( $output, $spid );
        };

        subtest 'has cookie' => sub {
            subtest 'Password match in session' => sub {
                my ( $app, $spid ) = SharedPreviewTest::make_shared_preview(
                    $super_author,      $blog1->id,
                    $content_data1->id, $content_type1->id
                );

                my $module = Test::MockModule->new('MT::App::SharedPreview');

                my $cookie_name = 'shared_preview_' . $blog1->id;
                my $make_session
                    = SharedPreview::Auth::make_session( $app, $blog1->id,
                    'test' );

                $module->mock(
                    'cookies',
                    sub {
                        my $app     = shift;
                        my $cookies = {};
                        $cookies->{$cookie_name}->{value}[0]
                            = $make_session->id;
                        return $cookies;
                    }
                );

                my $output
                    = SharedPreviewTest::request_show_shared_preview($spid);
                ok( $output, 'Output' ) or return;
                SharedPreviewTest::check_shared_preview( $output, $blog1->id,
                    $content_data1, $spid, $content_type1->id );
            };

            subtest 'Password mismatch in session' => sub {
                my $blog_id         = $blog1->id;
                my $content_data_id = $content_data1->id;

                my ( $app, $spid )
                    = SharedPreviewTest::make_shared_preview( $super_author,
                    $blog_id, $content_data_id, $content_type1->id );

                my $module = Test::MockModule->new('MT::App::SharedPreview');

                my $cookie_name = 'shared_preview_' . $blog_id;
                my $make_session
                    = SharedPreview::Auth::make_session( $app, $blog_id,
                    'nopassword' );

                $module->mock(
                    'cookies',
                    sub {
                        my $app     = shift;
                        my $cookies = {};
                        $cookies->{$cookie_name}->{value}[0]
                            = $make_session->id;
                        return $cookies;
                    }
                );

                my $output
                    = SharedPreviewTest::request_show_shared_preview($spid);
                ok( $output, 'Output' ) or return;
                SharedPreviewTest::check_redirect_login( $output, $spid );

                my $after_session = MT::Session->load( $make_session->id );
                ok( !$after_session, 'Session deleted successfully' );
            };
        };
    };

    subtest 'no need to login' => sub {
        my ( $app, $spid ) = SharedPreviewTest::make_shared_preview(
            $super_author,      $blog2->id,
            $content_data2->id, $content_type2->id
        );

        my $output = SharedPreviewTest::request_show_shared_preview($spid);
        ok( $output, 'Output' ) or return;
        SharedPreviewTest::check_shared_preview( $output, $blog2->id,
            $content_data2, $spid, $content_type2->id );
    };

    subtest 'Parameter Check' => sub {
        subtest 'empty spid' => sub {
            my $spid = '';
            my $output
                = SharedPreviewTest::request_show_shared_preview($spid);
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_page_not_found($output);
        };

        subtest 'undefined spid' => sub {
            my $spid = '999999999999999999999999';
            my $output
                = SharedPreviewTest::request_show_shared_preview($spid);
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_page_not_found($output);
        };

        subtest 'not found spid from preview data' => sub {
            my $preview = MT::Preview->new;
            $preview->blog_id(999999);
            $preview->object_id(1);
            $preview->object_type('content_data');
            $preview->id( $preview->make_unique_id );
            $preview->content_type_id( $content_type1->id );
            $preview->save;

            my $spid = $preview->id;

            my $output
                = SharedPreviewTest::request_show_shared_preview($spid);
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_page_not_found($output);
        };

        subtest 'not found blog_id from preview data' => sub {
            my $spid = '';
            my $output
                = SharedPreviewTest::request_show_shared_preview($spid);
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_page_not_found($output);
        };
    };
};

done_testing;
