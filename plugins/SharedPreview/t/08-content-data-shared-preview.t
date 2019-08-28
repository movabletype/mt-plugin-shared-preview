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
}

use MT;
use MT::Test;
use SharedPreviewTest;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name = 'SharedPreviewBlog1-' . time();

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
        blog => [ { name => $blog1_name, }, ],
    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;

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

my $content_type1 = MT::Test::Permission->make_content_type(
    name    => 'test content type 1',
    blog_id => $blog1->id,
);

my $content_field1 = MT::Test::Permission->make_content_field(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    name            => 'single line text',
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

$content_type1->fields($fields1);
$content_type1->save or die;

my $content_data1 = MT::Test::Permission->make_content_data(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    status          => MT::ContentStatus::RELEASE(),
    data => { $content_field1->id => 'test single line text (RELEASE)', },
    author_id   => $create_post_author->id,
    authored_on => '2019-08-01',
);

my $content_data2 = MT::Test::Permission->make_content_data(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    status          => MT::ContentStatus::HOLD(),
    data        => { $content_field1->id => 'test single line text (HOLD)', },
    author_id   => $super_author->id,
    authored_on => '2019-08-01',
);

my $content_data3 = MT::Test::Permission->make_content_data(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    status          => MT::ContentStatus::HOLD(),
    data        => { $content_field1->id => 'test single line text (HOLD)', },
    author_id   => $super_author->id,
    authored_on => '2019-08-01',
);

my $plugin_data = MT::Test::Permission->make_plugindata(
    plugin => 'SharedPreview',
    key    => 'configuration:blog:' . $blog1->id,
    data   => { 'sp_password[]' => [ 'test', 'test2' ] }
);

subtest 'content data page' => sub {
    subtest 'create new content data' => sub {
        my $output = request_content_data_page( $super_author, $blog1->id,
            $content_type1->id, '', 'content_data', '' );
        ok( $output, 'Output' ) or return;
        unlike( $output, qr/An error occurred/, 'no error' ) or return;
        unlike( $output, qr/shared-preview-widget/, 'shared preview widget' );
        unlike(
            $output,
            qr/__mode=make_shared_preview/,
            'shared preview link'
        );
        unlike( $output, qr/Open the shared preview/,
            'shared preview label' );
    };

    subtest 'edit content data' => sub {
        subtest 'published' => sub {
            my $output = request_content_data_page( $super_author, $blog1->id,
                $content_type1->id, $content_data1->id, 'content_data', '' );
            ok( $output, 'Output' ) or return;
            unlike( $output, qr/An error occurred/, 'no error' ) or return;
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
            my $output = request_content_data_page( $super_author, $blog1->id,
                $content_type1->id, $content_data2->id, 'content_data', '' );
            ok( $output, 'Output' ) or return;
            unlike( $output, qr/An error occurred/, 'no error' ) or return;

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
            is( $uri->query_param('id'), $content_data2->id, 'correct id' );

        };
    };

    subtest 'save content_data' => sub {
        subtest 'unpublished to published' => sub {
            my $make_preview = SharedPreviewTest::make_shared_preview(
                $super_author,      $blog1->id,
                $content_data3->id, $content_type1->id
            ) or return;
            my $output = request_save_content_data( $super_author, $blog1->id,
                $content_type1->id, $content_data3->id, 2, 0 );
            ok( $output, 'Output' ) or return;

            my $after_preview = MT->model('preview')->load($make_preview);
            ok( !$after_preview, 'Shared preview removed' );
        };
    };

    subtest 'saved added content_data page' => sub {
        subtest 'published' => sub {
            my $output
                = request_content_data_page( $super_author, $blog1->id,
                $content_type1->id, $content_data1->id, 'content_data',
                'added' );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-added'\)\.append.*href=\\"(.*?)\\"/;
            ok( !$make_shared_preview_link, 'shared preview link' );
        };

        subtest 'unpublished' => sub {
            my $output
                = request_content_data_page( $super_author, $blog1->id,
                $content_type1->id, $content_data2->id, 'content_data',
                'added' );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-added'\)\.after.*href=\\"(.*?)\\"/;
            my $uri = URI->new($make_shared_preview_link);

            is( $uri->query_param('__mode'),
                'make_shared_preview', 'correct mode' );
            is( $uri->query_param('blog_id'), $blog1->id, 'correct blog_id' );
            is( $uri->query_param('id'), $content_data2->id, 'correct id' );
        };

    };

    subtest 'saved changes content_data page' => sub {
        subtest 'published' => sub {
            my $output
                = request_content_data_page( $super_author, $blog1->id,
                $content_type1->id, $content_data1->id, 'content_data',
                'changes' );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-changes'\)\.append.*href=\\"(.*?)\\"/;
            ok( !$make_shared_preview_link, 'shared preview link' );

        };

        subtest 'unpublished' => sub {
            my $output
                = request_content_data_page( $super_author, $blog1->id,
                $content_type1->id, $content_data2->id, 'content_data',
                'changes' );
            ok( $output, 'Output' ) or return;

            my ($make_shared_preview_link)
                = $output
                =~ m/jQuery\('#saved-changes'\)\.append.*href=\\"(.*?)\\"/;
            my $uri = URI->new($make_shared_preview_link);

            is( $uri->query_param('__mode'),
                'make_shared_preview', 'correct mode' );
            is( $uri->query_param('blog_id'), $blog1->id, 'correct blog_id' );
            is( $uri->query_param('id'), $content_data2->id, 'correct id' );
            is( $uri->query_param('content_type_id'),
                $content_type1->id, 'correct content_type_id' );

        };

    };
};

sub request_content_data_page {
    my ( $author, $blog_id, $content_type_id, $content_data_id, $type,
        $saved )
        = @_;

    my %parameters = (
        __test_user             => $author,
        __test_follow_redirects => 1,
        __mode                  => 'view',
        _type                   => $type,
        type                    => $type . '_' . $content_type_id,
        blog_id                 => $blog_id,
        content_type_id         => $content_type_id
    );
    $parameters{id} = $content_data_id if $content_data_id;

    if ($saved) {
        $parameters{saved_added}   = 1 if $saved eq 'added';
        $parameters{saved_changes} = 1 if $saved eq 'changes';
    }

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub request_save_content_data {
    my ( $author, $blog_id, $content_type_id, $content_data_id, $status,
        $redirects )
        = @_;
    my $content_data_type  = 'content_data' . '_' . $content_type_id;
    my $content_type_field = 'content-field-' . $content_field1->id;
    my %parameters         = (
        __test_user             => $author,
        __test_follow_redirects => $redirects,
        author_id               => $author->id,
        blog_id                 => $blog_id,
        __mode                  => 'save',
        content_type_id         => $content_type_id,
        _type                   => 'content_data',
        return_args =>
            "__mode=view&type=$content_data_type&_type=content_data&blog_id=$blog_id&content_type_id=$content_type_id",
        save_revision       => 1,
        data_label          => 'test',
        $content_type_field => 'test',
        status              => $status,
        authored_on_date    => '2019-08-02',
        authored_on_year    => '2019',
        authored_on_month   => '08',
        authored_on_day     => '02',
        authored_on_time    => '05:09:03',
        authored_on_hour    => '05',
        authored_on_minute  => '09',
        authored_on_second  => '03',
        basename            => 'content_data' . time(),
        basename_manual     => 0,
        allow_comments      => 1,
    );

    $parameters{id} = $content_data_id if $content_data_id;

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my $output = delete $app->{__test_output};
    return $output || '';
}

done_testing;
