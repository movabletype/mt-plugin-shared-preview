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

    $ENV{MT_CONFIG} = $test_env->config_file;
    $ENV{MT_APP}    = 'MT::App::CMS';
}

use MT;
use MT::Test;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name  = 'SharedPreviewBlog1';
my $blog2_name  = 'SharedPreviewBlog2';
my $entry1_name = 'SharedPreviewEntry1';
my $entry2_name = 'SharedPreviewEntry2';

my $super          = 'super';
my $create_post    = 'create_post';
my $edit_all_posts = 'edit_all_posts';
my $not_permission = 'not_permission';

my $objs = MT::Test::Fixture->prepare(
    {   author => [
            { 'name' => $super },
            { 'name' => $create_post, is_superuser => 0 },
            { 'name' => $edit_all_posts, is_superuser => 0 },
            { 'name' => $not_permission, is_superuser => 0 },
        ],
        blog  => [ { name => $blog1_name, }, ],
        entry => [
            {   basename    => $entry1_name,
                title       => $entry1_name,
                author      => $create_post,
                status      => 'draft',
                authored_on => '20190703121110',
            },
            {   basename    => $entry2_name,
                title       => $entry2_name,
                author      => $super,
                status      => 'draft',
                authored_on => '20190703121110',
            },
        ]
    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;
my $entry1 = MT->model('entry')->load( { basename => $entry1_name } ) or die;
my $entry2 = MT->model('entry')->load( { basename => $entry2_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;
my $create_post_author = MT->model('author')->load( { name => $create_post } )
    or die;

my $edit_all_posts_author
    = MT->model('author')->load( { name => $edit_all_posts } )
    or die;

my $not_permissions_text
    = "'create_site', 'edit_assets', 'edit_categories', 'edit_config', 'edit_notifications', 'edit_tags', 'manage_category_set', 'manage_member_blogs', 'manage_pages', 'manage_plugins', 'manage_themes', 'manage_users', 'manage_users_groups', 'publish_post', 'rebuild', 'send_notifications', 'set_publish_paths', 'sign_in_cms', 'sign_in_data_api', 'send_notifications', 'upload', 'view_blog_log', 'view_log'";
my $not_permission_author
    = MT->model('author')->load( { name => $not_permission } )
    or die;

my $create_post_role = MT::Test::Permission->make_role(
    name        => 'Create Post',
    permissions => "'$create_post'",
);

my $edit_all_posts_role = MT::Test::Permission->make_role(
    name        => 'Edit All Post',
    permissions => "'$edit_all_posts'",
);

my $no_permission_role = MT::Test::Permission->make_role(
    name        => 'Can not Make Shared Preview',
    permissions => $not_permissions_text,
);

MT::Association->link( $create_post_author,    $create_post_role,    $blog1 );
MT::Association->link( $edit_all_posts_author, $edit_all_posts_role, $blog1 );
MT::Association->link( $not_permission_author, $no_permission_role,  $blog1 );

subtest 'make_shared_preview' => sub {
    my $type = 'entry';
    subtest 'Users who can create share previews' => sub {
        subtest 'create_post user' => sub {
            subtest 'entry created by create_post user' => sub {
                my $output
                    = request_make_shared_preview( $create_post_author,
                    $blog1->id, $entry1->id, $type );
                ok( $output, 'Output Success' );
                check_response_make_shared_preview( $output, $blog1,
                    $entry1 );
                done_testing;
            };

            subtest 'entry created by super user' => sub {
                my $output
                    = request_make_shared_preview( $create_post_author,
                    $blog1->id, $entry2->id, $type );
                ok( $output, 'Output Success' );
                check_response_permission_error($output);
                done_testing;
            };
            done_testing;
        };

        subtest 'edit_all_posts user' => sub {
            my $output = request_make_shared_preview( $edit_all_posts_author,
                $blog1->id, $entry1->id, $type );
            ok( $output, 'Output Success' );
            check_response_make_shared_preview( $output, $blog1, $entry1 );
            done_testing;
        };

        subtest 'super user' => sub {
            my $output = request_make_shared_preview( $super_author,
                $blog1->id, $entry1->id, $type );
            ok( $output, 'Output Success' );
            check_response_make_shared_preview( $output, $blog1, $entry1 );
            done_testing;
        };
        done_testing;
    };

    subtest "Users who can't create share previews" => sub {
        my $type = 'entry';
        my $output
            = request_make_shared_preview( $not_permission_author,
            $blog1->id, $entry1->id, $type );
        ok( $output, 'Output Success' );
        check_response_permission_error($output);

        done_testing;
    };

    subtest 'Request parameter check' => sub {
        subtest '_type is empty' => sub {
            my $output
                = request_make_shared_preview( $super_author,
                $blog1->id, $entry1->id, '' );
            ok( $output, 'Output Success' );
            ok( $output =~ m/Invalid request/,
                'Invalid request error message output success.' );
            done_testing;
        };

        subtest 'id is empty' => sub {
            my $output
                = request_make_shared_preview( $super_author,
                $blog1->id, '', $type );
            ok( $output, 'Output Success' );
            ok( $output =~ m/Invalid request/,
                'Invalid request error message output success.' );
            done_testing;
        };

        subtest 'type is not found' => sub {
            my $output
                = request_make_shared_preview( $super_author,
                $blog1->id, $entry1->id, 'test_shared_preview' );
            ok( $output, 'Output Success' );
            ok( $output =~ m/Invalid type: test_shared_preview/,
                'Invalid request error message output success.'
            );
            done_testing;
        };
        done_testing;
    };

    subtest 'shared preview data is found' => sub {
        my $before_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $entry1->id,
                object_type => 'entry'
            }
        );

        my $output
            = request_make_shared_preview( $super_author,
            $blog1->id, $entry1->id, $type );

        ok( $output, 'Output Success' );
        check_response_make_shared_preview( $output, $blog1, $entry1 );

        my $after_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $entry1->id,
                object_type => 'entry'
            }
        );

        is( $before_preview->id, $after_preview->id,
            'Not created a shared preview.' );

        done_testing;
    };

    subtest 'shared preview data not found' => sub {
        my $before_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $entry2->id,
                object_type => 'entry'
            }
        );

        my $output
            = request_make_shared_preview( $super_author,
            $blog1->id, $entry2->id, $type );

        ok( $output, 'Output Success' );
        check_response_make_shared_preview( $output, $blog1, $entry2 );

        my $after_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $entry2->id,
                object_type => 'entry'
            }
        );

        ok( !$before_preview,   'Not created a shared preview.' );
        ok( $after_preview->id, 'Created a new shared preview.' );

        done_testing;
    };

    done_testing;
};

sub request_make_shared_preview {
    my ( $author, $blog_id, $entry_id, $type ) = @_;
    my $app = _run_app(
        'MT::App::CMS',
        {   __test_user             => $author,
            __test_follow_redirects => 1,
            __mode                  => 'make_shared_preview',
            _type                   => $type,
            blog_id                 => $blog_id,
            id                      => $entry_id,
        },
    );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub check_response_make_shared_preview {
    my ( $output, $blog, $entry ) = @_;
    my $preview = MT->model('preview')->load(
        {   blog_id     => $blog->id,
            object_id   => $entry->id,
            object_type => 'entry'
        }
    );
    ok( $preview, 'Success in creating shared preview' );

    my $spid = '';
    $spid = $preview->id if $preview;

    ok( $spid, 'Success in creating share preview' );
    ok( $output =~ m/Status: 302 Found/, 'is redirect' );
    ok( $output
            =~ m/Location: .*mt-shared-preview.cgi.*(?=.*__mode=shared_preview)(?=.*spid=$spid)/,
        'is shared preview url'
    );
}

sub check_response_permission_error {
    my ($output) = @_;
    ok( $output =~ m/Status: 200/, 'Status is 200' );
    ok( $output
            =~ m/You attempted to use a feature that you do not have permission to access. If you believe you are seeing this message in error contact your system administrator./,
        'Permission error message output success.'
    );
}
done_testing;
