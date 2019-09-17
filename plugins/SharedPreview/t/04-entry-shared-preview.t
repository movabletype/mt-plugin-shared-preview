use strict;
use warnings;
use FindBin;
use Cwd;

use lib Cwd::realpath("./t/lib"), "$FindBin::Bin/lib";
use Test::More;
use MT::Test::Env;

our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new(
        PluginPath => [ Cwd::realpath("$FindBin::Bin/../../../plugins") ], );

    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT;
use MT::Test;
use MT::Test::Fixture;
use MT::Test::Permission;
use MT::Association;
use SharedPreviewTest;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name  = 'SharedPreviewBlog1-' . time();
my $entry1_name = 'SharedPreviewEntry1-' . time();
my $entry2_name = 'SharedPreviewEntry2-' . time();
my $entry3_name = 'SharedPreviewEntry3-' . time();

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
            {   basename    => $entry3_name,
                title       => $entry3_name,
                author      => $super,
                status      => 'publish',
                authored_on => '20190703121110',
            },
        ]
    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;
my $entry1 = MT->model('entry')->load( { basename => $entry1_name } ) or die;
my $entry2 = MT->model('entry')->load( { basename => $entry2_name } ) or die;
my $entry3 = MT->model('entry')->load( { basename => $entry3_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;
my $create_post_author = MT->model('author')->load( { name => $create_post } )
    or die;

my $edit_all_posts_author
    = MT->model('author')->load( { name => $edit_all_posts } )
    or die;

my $not_permission_author
    = MT->model('author')->load( { name => $not_permission } )
    or die;

my $create_post_role = MT::Test::Permission->make_role(
    name        => 'Create Post',
    permissions => "'create_post'",
);

my $edit_all_posts_role = MT::Test::Permission->make_role(
    name        => 'Edit All Post',
    permissions => "'edit_all_posts'",
);

my $no_permission_role = MT::Test::Permission->make_role(
    name => 'Can not Make Shared Preview',
    permissions =>
        "'create_site', 'edit_assets', 'edit_categories', 'edit_config', 'edit_notifications', 'edit_tags', 'manage_category_set', 'manage_member_blogs', 'manage_pages', 'manage_plugins', 'manage_themes', 'manage_users', 'manage_users_groups', 'publish_post', 'rebuild', 'send_notifications', 'set_publish_paths', 'sign_in_cms', 'sign_in_data_api', 'send_notifications', 'upload', 'view_blog_log', 'view_log'",
);

MT::Association->link( $create_post_author,    $create_post_role,    $blog1 );
MT::Association->link( $edit_all_posts_author, $edit_all_posts_role, $blog1 );
MT::Association->link( $not_permission_author, $no_permission_role,  $blog1 );

my $plugin_data = MT::Test::Permission->make_plugindata(
    plugin => 'SharedPreview',
    key    => 'configuration:blog:' . $blog1->id,
    data   => { 'sp_password[]' => [ 'test', 'test2' ] }
);

subtest 'entry page' => sub {
    subtest 'create new entry' => sub {
        my $output
            = request_entry_page( $super_author, $blog1->id, '', 'entry',
            '' );
        ok( $output, 'Output' ) or return;
        unlike( $output, qr/shared-preview-widget/, 'shared preview widget' );
        unlike(
            $output,
            qr/__mode=make_shared_preview/,
            'shared preview link'
        );
        unlike( $output, qr/Open the shared preview/,
            'shared preview label' );
    };

    subtest 'edit entry' => sub {
        subtest 'published' => sub {
            my $output
                = request_entry_page( $super_author, $blog1->id, $entry3->id,
                'entry', '' );
            ok( $output, 'Output' ) or return;
            unlike( $output, qr/shared-preview-widget/,
                'shared preview widget' );
            unlike(
                $output,
                qr/__mode=make_shared_preview/,
                'shared preview link'
            );
            unlike(
                $output,
                qr/Open the shared preview/,
                'shared preview label'
            );

        };

        subtest 'unpublished' => sub {
            my $output
                = request_entry_page( $super_author, $blog1->id, $entry1->id,
                'entry', '' );
            ok( $output, 'Output' ) or return;

            like( $output, qr/shared-preview-widget/,
                'shared preview widget' );
            like(
                $output,
                qr/__mode=make_shared_preview/,
                'shared preview link'
            );
            like(
                $output,
                qr/Open the shared preview/,
                'shared preview label'
            );

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#entry-publishing-widget'\)\.before.*href=\\"(.*?)\\"\s/;
            ok( $make_shared_preview_link, 'make shared preview link' )
                or return;

            my $uri = URI->new($make_shared_preview_link);
            is( $uri->query_param('__mode'),
                'make_shared_preview', 'correct mode' );
            is( $uri->query_param('blog_id'), $blog1->id, 'correct blog_id' );
            is( $uri->query_param('id'), $entry1->id, 'correct blog_id' );

        };
    };

    subtest 'save entry' => sub {
        subtest 'unpublished to published' => sub {
            my ( $app, $make_preview )
                = SharedPreviewTest::make_shared_preview( $super_author,
                $blog1->id, $entry2->id )
                or return;
            my $output
                = request_save_entry( $super_author, $blog1->id, $entry2, 2,
                0 );
            ok( $output, 'Output' ) or return;

            my $after_preview = MT->model('preview')->load($make_preview);
            ok( !$after_preview, 'Shared preview removed' );
        };
    };

    subtest 'saved added entry page' => sub {
        subtest 'published' => sub {
            my $output
                = request_entry_page( $super_author, $blog1->id, $entry3->id,
                'entry', 'added' );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-added'\)\.append.*href=\\"(.*?)\\"/;
            ok( !$make_shared_preview_link, 'shared preview link' );
        };

        subtest 'unpublished' => sub {
            my $output
                = request_entry_page( $super_author, $blog1->id, $entry1->id,
                'entry', 'added' );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-added'\)\.append.*href=\\"(.*?)\\"/;
            my $uri = URI->new($make_shared_preview_link);

            is( $uri->query_param('__mode'),
                'make_shared_preview', 'correct mode' );
            is( $uri->query_param('blog_id'), $blog1->id, 'correct blog_id' );
            is( $uri->query_param('id'), $entry1->id, 'correct blog_id' );
        };

    };

    subtest 'saved changes entry page' => sub {
        subtest 'published' => sub {
            my $output = request_entry_page(
                $super_author, $blog1->id, $entry3->id, 'entry',
                'changes'
            );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-changes'\)\.append.*href=\\"(.*?)\\"/;
            ok( !$make_shared_preview_link, 'shared preview link' );

        };

        subtest 'unpublished' => sub {
            my $output = request_entry_page(
                $super_author, $blog1->id, $entry1->id, 'entry',
                'changes'
            );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-changes'\)\.append.*href=\\"(.*?)\\"/;
            my $uri = URI->new($make_shared_preview_link);

            is( $uri->query_param('__mode'),
                'make_shared_preview', 'correct mode' );
            is( $uri->query_param('blog_id'), $blog1->id, 'correct blog_id' );
            is( $uri->query_param('id'), $entry1->id, 'correct blog_id' );

        };

    };
};

sub request_entry_page {
    my ( $author, $blog_id, $entry_id, $type, $saved ) = @_;

    my %parameters = (
        __test_user             => $author,
        __test_follow_redirects => 1,
        __mode                  => 'view',
        _type                   => $type,
        blog_id                 => $blog_id,
        id                      => $entry_id,
    );

    if ($saved) {
        $parameters{saved_added}   = 1 if $saved eq 'added';
        $parameters{saved_changes} = 1 if $saved eq 'changes';
    }

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub request_save_entry {
    my ( $author, $blog_id, $entry, $status, $redirects ) = @_;

    my %parameters = (
        __test_user             => $author,
        __test_follow_redirects => $redirects,
        author_id               => $author->id,
        blog_id                 => $blog_id,
        __mode                  => 'save_entry',
        _type                   => 'entry',
        return_args             => "__mode=view&_type=entry&blog_id=$blog_id",
        save_revision           => 1,
        entry_prefs             => 'Default',
        title                   => 'entry' . time(),
        convert_breaks          => 'richtext',
        convert_breaks_for_mobile => '_richtext',
        status                    => $status,
        authored_on_date          => '2019-07-02',
        authored_on_year          => '2019',
        authored_on_month         => '07',
        authored_on_day           => '02',
        authored_on_time          => '05:09:03',
        authored_on_hour          => '05',
        authored_on_minute        => '09',
        authored_on_second        => '03',
        basename                  => 'entry' . time(),
        basename_manual           => 0,
        allow_comments            => 1,
    );

    $parameters{id} = $entry->id if $entry;

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my $output = delete $app->{__test_output};
    return $output || '';
}

done_testing;
