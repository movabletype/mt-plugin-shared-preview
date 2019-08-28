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
use SharedPreviewTest;
use MT;
use MT::Test;
use MT::Preview;
use MT::Test::Fixture;
use MT::Test::Permission;
use MT::Association;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name  = 'SharedPreviewNeedPasswordBlog1-' . time();
my $blog2_name  = 'SharedPreviewNoPasswordBlog2-' . time();
my $entry1_name = 'SharedPreviewEntry1-' . time();
my $entry2_name = 'SharedPreviewEntry2-' . time();

my $super = 'super';

my $objs = MT::Test::Fixture->prepare(
    {   author => [ { 'name' => $super }, ],
        blog   => [ { name   => $blog1_name, }, { name => $blog2_name, }, ],

    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;
my $blog2 = MT->model('blog')->load( { name => $blog2_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;

my $entry1 = MT::Test::Permission->make_entry(
    basename    => $entry1_name,
    title       => $entry1_name,
    author      => $super,
    status      => 1,
    authored_on => '20190703121110',
    blog_id     => $blog1->id
);

my $entry2 = MT::Test::Permission->make_entry(
    basename    => $entry2_name,
    title       => $entry2_name,
    author      => $super,
    status      => 1,
    authored_on => '20190703121110',
    blog_id     => $blog2->id
);

my $plugin_data = MT::Test::Permission->make_plugindata(
    plugin => 'SharedPreview',
    key    => 'configuration:blog:' . $blog1->id,
    data   => { 'sp_password[]' => [ 'test', 'test2' ] }
);

my ( $app1, $need_password_spid )
    = SharedPreviewTest::make_shared_preview( $super_author, $blog1->id,
    $entry1->id );
my ( $app2, $no_password_spid )
    = SharedPreviewTest::make_shared_preview( $super_author, $blog2->id,
    $entry2->id );

subtest 'login_shared_preview' => sub {
    subtest 'Not need login' => sub {
        my $output = get_request_login($no_password_spid);
        ok( $output, 'Output' ) or return;
        SharedPreviewTest::check_redirect_shared_preview( $output,
            $no_password_spid );
    };

    subtest 'Need login' => sub {
        subtest 'not logined' => sub {
            subtest 'get request' => sub {
                my $output = get_request_login($need_password_spid);
                ok( $output, 'Output' ) or return;
                check_login( $output, $blog1, $need_password_spid, '' );
            };
        };

        subtest 'Logged in' => sub {
            my $module = Test::MockModule->new('MT::App::SharedPreview');

            my $cookie_name = 'shared_preview_' . $blog1->id;
            my $app         = MT::App::SharedPreview->app;
            my $make_session
                = SharedPreview::Auth::make_session( $app, $blog1->id,
                'test' );

            $module->mock(
                'cookies',
                sub {
                    my $app     = shift;
                    my $cookies = {};
                    $cookies->{$cookie_name}->{value}[0] = $make_session->id;
                    return $cookies;
                }
            );

            my $output = get_request_login($need_password_spid);
            ok( $output, 'Output' ) or return;
            check_login( $output, $blog1, $need_password_spid, '' );
        };

        subtest 'Enter password and login' => sub {
            subtest 'Login successful' => sub {
                my $output
                    = post_request_login( $need_password_spid, 'test', '' );
                ok( $output, 'Output' ) or return;
                SharedPreviewTest::check_redirect_shared_preview( $output,
                    $need_password_spid );
            };

            subtest 'Login failure' => sub {
                subtest 'Password not entered' => sub {
                    my $output
                        = post_request_login( $need_password_spid, '', '' );
                    ok( $output, 'Output' ) or return;
                    check_login( $output, $blog1, $need_password_spid,
                        'You must supply a password.' );
                };

                subtest 'Password mismatch' => sub {
                    my $output = post_request_login( $need_password_spid,
                        'mismatch', '' );
                    ok( $output, 'Output' ) or return;
                    check_login( $output, $blog1, $need_password_spid,
                        'Passwords do not match.' );
                };

                subtest 'Failed to create session' => sub {
                    my $module = Test::MockModule->new('SharedPreview::Auth');
                    $module->mock(
                        'start_session',
                        sub {
                            return 'Failed to create session';
                        }
                    );

                    my $output
                        = post_request_login( $need_password_spid, 'test',
                        '' );
                    ok( $output, 'Output' ) or return;
                    check_login( $output, $blog1, $need_password_spid,
                        'Failed to create session' );
                };
            };
        };
    };
};

sub get_request_login {
    my ($spid) = @_;
    my $app = _run_app(
        'MT::App::SharedPreview',
        {   __test_follow_redirects => 1,
            __request_method        => 'GET',
            __mode                  => 'shared_preview_login',
            spid                    => $spid,
        },
    );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub post_request_login {
    my ( $spid, $password, $remember ) = @_;
    my $app = _run_app(
        'MT::App::SharedPreview',
        {   __test_follow_redirects => 1,
            __request_method        => 'POST',
            __mode                  => 'shared_preview_login',
            spid                    => $spid,
            password                => $password,
            sp_remember             => $remember,
        },
    );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub check_login {
    my ( $output, $blog, $spid, $message ) = @_;
    like( $output, qr/Status: 401/, 'status is 401' );

    my $site_url  = $blog->site_url;
    my $site_name = $blog->name;
    like(
        $output,
        qr/In order to view shared preview of <a href="$site_url">$site_name<\/a>, password is required\./,
        'login message'
    );

    like(
        $output,
        qr/This password is different from your login password\./,
        'password message'
    );

    like( $output, qr/Remember me\?/, 'Remember message' );

    if ($message) {
        like( $output, qr/$message/, 'error message' );
    }
}

done_testing;
