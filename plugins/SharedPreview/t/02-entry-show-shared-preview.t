use strict;
use warnings;
use FindBin;
use Cwd;

use lib Cwd::realpath("./t/lib");
use Test::More;
use MT::Test::Env;
use MT::Test::Fixture;
use MT::Test::Permission;
use MT::Association;

our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new(
        PluginPath => [ Cwd::realpath("$FindBin::Bin/../../../plugins") ], );

    eval { require Test::MockModule }
        or plan skip_all => 'Test::MockModule is not installed';

    $ENV{MT_CONFIG} = $test_env->config_file;
    $ENV{MT_APP}    = 'MT::App::CMS';
}

use MT;
use MT::Test;
use SharedPreview::Auth;
use MT::Preview;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name   = 'SharedPreviewNeedPasswordBlog1';
my $blog2_name   = 'SharedPreviewNoPasswordBlog2';
my $entry1_name  = 'SharedPreviewEntry1';
my $entry2_name   = 'SharedPreviewEntry2';

my $super        = 'super';

my $objs = MT::Test::Fixture->prepare(
    {   author => [
            { 'name' => $super },
        ],
        blog  => [
            { name => $blog1_name, },
            { name => $blog2_name, },
        ],

    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;
my $blog2 = MT->model('blog')->load( { name => $blog2_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;

my $entry1 = MT::Test::Permission->make_entry(
    basename      => $entry1_name,
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
    key     => 'configuration:blog:' . $blog1->id,
    data    => {'sp_password[]' => ['test', 'test2'], use_password => 1}
);

subtest 'show_shared_preview' => sub {
    subtest 'need to login' => sub {
        subtest 'no cookie' => sub {
            my ($app, $spid)
                = make_shared_preview($super_author, $blog1->id,
                $entry1->id);

            my $output = request_show_shared_preview($spid);
            ok($output, 'Output Success');
            check_redirect_login($output, $spid);
            done_testing;
        };

        subtest 'has cookie' => sub {
            subtest 'Password match in session' => sub {
                my ($app, $spid)
                    = make_shared_preview($super_author, $blog1->id,
                    $entry1->id);

                my $module = Test::MockModule->new('MT::App::SharedPreview');

                my $cookie_name = 'shared_preview_' . $blog1->id;
                my $make_session = SharedPreview::Auth::make_session( $app, $blog1->id, 'test');

                $module->mock( 'cookies', sub {
                    my $app = shift;
                    my $cookies = {};
                    $cookies->{$cookie_name}->{value}[0] = $make_session->id;
                    return $cookies;
                });

                my $output = request_show_shared_preview($spid);
                ok($output, 'Output Success');
                check_shared_preview($output, $blog1, $entry1, $spid);
                done_testing;
            };

            subtest 'Password mismatch in session' => sub {
                my $blog_id = $blog1->id;
                my $entry_id = $entry1->id;

                my ($app, $spid)
                    = make_shared_preview($super_author, $blog_id,
                    $entry_id);

                my $module = Test::MockModule->new('MT::App::SharedPreview');

                my $cookie_name = 'shared_preview_' . $blog_id;
                my $make_session = SharedPreview::Auth::make_session( $app, $blog_id, 'nopassword');

                $module->mock( 'cookies', sub {
                    my $app = shift;
                    my $cookies = {};
                    $cookies->{$cookie_name}->{value}[0] = $make_session->id;
                    return $cookies;
                });

                my $output = request_show_shared_preview($spid);
                ok($output, 'Output Success');
                check_redirect_login($output, $spid);

                my $after_session = MT::Session->load($make_session->id);
                ok(!$after_session, 'Session deleted successfully');

                done_testing;
            };

            done_testing;
        };

        done_testing;
    };

    subtest 'no need to login' => sub {
        my ($app, $spid)
            = make_shared_preview($super_author, $blog2->id,
            $entry2->id);

        my $output = request_show_shared_preview($spid);
        ok($output, 'Output Success');
        check_shared_preview($output, $blog2, $entry2, $spid);

        done_testing;
    };

    subtest 'Parameter Check' => sub {
        subtest 'empty spid' => sub {
            my $spid = '';
            my $output = request_show_shared_preview($spid);
            ok($output, 'Output Success');
            check_page_not_found($output);
        };

        subtest 'undefined spid' => sub {
            my $spid = '999999999999999999999999';
            my $output = request_show_shared_preview($spid);
            ok($output, 'Output Success');
            check_page_not_found($output);
            done_testing
        };

        subtest 'not found spid from preview data' => sub {
            my $preview = MT::Preview->new;
            $preview->blog_id(999999);
            $preview->object_id(1);
            $preview->object_type('entry');
            $preview->id( $preview->make_unique_id );
            $preview->save;

            my $spid = $preview->id;

            my $output = request_show_shared_preview($spid);
            ok($output, 'Output Success');
            check_page_not_found($output);
            done_testing;
        };

        subtest 'not found blog_id from preview data' => sub {
            my $spid = '';
            my $output = request_show_shared_preview($spid);
            ok($output, 'Output Success');
            check_page_not_found($output);
            done_testing;
        };

        done_testing;
    };

    done_testing;
};

sub request_show_shared_preview {
    my ( $spid ) = @_;
    my $app = _run_app(
        'MT::App::SharedPreview',
        {
            __test_follow_redirects => 1,
            __mode                  => 'shared_preview',
            spid                    => $spid,
        },
    );

    my $output = delete $app->{__test_output};
    return $output || '';
}


sub make_shared_preview {
    my ( $author, $blog_id, $entry_id) = @_;
    my $app = _run_app(
        'MT::App::CMS',
        {   __test_user             => $author,
            __test_follow_redirects => 1,
            __mode                  => 'make_shared_preview',
            _type                   => 'entry',
            blog_id                 => $blog_id,
            id                      => $entry_id,
        },
    );

    my $preview = MT->model('preview')->load(
        {   blog_id     => $blog_id,
            object_id   => $entry_id,
            object_type => 'entry'
        }
    );

    return ($app, $preview->id);
}

sub check_redirect_login {
    my ($output, $spid) = @_;
    ok($output, 'Output Success');
    ok($output =~ m/Status: 302 Found/, 'is redirect');
    ok($output
        =~ m/Location: .*(__mode=shared_preview_login).*(spid=$spid)/,
        'is shared preview login url'
    );
}

sub check_shared_preview {
    my ($output, $blog, $entry, $spid) = @_;

    my $blog_id = $blog->id;
    my $entry_id = $entry->id;
    my $permalink = MT::Util::encode_html( $entry->permalink );

    ok($output =~ m/Status: 200/, 'Status is 200');
    ok($output
        =~ m/mt-sharedPreviewNav/,
        'is shared preview page'
    );
    ok($output
        =~ m/(__mode=view).*(id="edit")/ &&
        $output =~ m/(id=$entry_id).*(id="edit")/ &&
        $output =~ m/(blog_id=$blog_id).*(id="edit")/ &&
        $output =~ m/(_type=entry).*(id="edit")/
        ,
        'entry edit link'
    );
    ok($output
        =~ m/.*(id="show-preview-url").*(__mode=shared_preview)/
        && $output =~ m/.*(id="show-preview-url").*(spid=$spid)/,
        'entry shared preview link'
    );
    ok($output
        =~ m/(?=.*id="show-permalink").*(data-href="$permalink")/,
        'entry permalink link'
    );

}

sub check_page_not_found {
    my ($output) = @_;
    ok($output =~ m/Status: 404/, 'Status is 404');
    ok($output =~ m/Page Not Found/, 'Page Not Found');
}

done_testing;
