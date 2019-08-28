use strict;
use warnings;
use FindBin;
use Cwd;

use lib Cwd::realpath("./t/lib");
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
use SharedPreviewTest;
use MT::Test::Fixture;
use MT::Test::Permission;
use MT::Association;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name = 'SharedPreviewBlog1-' . time();

my $super = 'super';

my $not_permission = 'not_permission';

my $objs = MT::Test::Fixture->prepare(
    {   author => [
            { 'name' => $super },
            { 'name' => $not_permission, is_superuser => 0 },
        ],
        blog => [ { name => $blog1_name, }, ],
    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;

my $not_permission_author
    = MT->model('author')->load( { name => $not_permission } )
    or die;

my $no_permission_role = MT::Test::Permission->make_role(
    name => 'no permission',
    permissions =>
        "'create_site', 'edit_assets', 'edit_categories', 'edit_config', 'edit_notifications', 'edit_tags', 'manage_category_set', 'manage_member_blogs', 'manage_pages', 'manage_plugins', 'manage_themes', 'manage_users', 'manage_users_groups', 'publish_post', 'rebuild', 'send_notifications', 'set_publish_paths', 'sign_in_cms', 'sign_in_data_api', 'send_notifications', 'upload', 'view_blog_log', 'view_log'",
);

MT::Association->link( $not_permission_author, $no_permission_role, $blog1 );

my $content_type1 = MT::Test::Permission->make_content_type(
    name    => 'test content type 1',
    blog_id => $blog1->id,
);

my $content_type2 = MT::Test::Permission->make_content_type(
    name    => 'test content type 2',
    blog_id => $blog1->id,
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

my $create_content_data = 'create_content_data:' . $content_type1->unique_id;

my $create_content_data_author = MT::Test::Permission->make_author(
    'name'       => 'Create Content Data',
    'nickname'   => 'Create Content Data',
    is_superuser => 0
);

my $create_content_data_role = MT::Test::Permission->make_role(
    name        => 'Create Content Data',
    permissions => "'$create_content_data'",
);

MT::Association->link( $create_content_data_author,
    $create_content_data_role, $blog1 );

my $content_data1 = MT::Test::Permission->make_content_data(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    status          => MT::ContentStatus::RELEASE(),
    data => { $content_field1->id => 'test single line text (RELEASE)', },
    author_id   => $create_content_data_author->id,
    authored_on => '2019-08-01',
);

my $content_data2 = MT::Test::Permission->make_content_data(
    blog_id         => $content_type1->blog_id,
    content_type_id => $content_type1->id,
    status          => MT::ContentStatus::RELEASE(),
    data        => { $content_field1->id => 'test single line text (HOLD)', },
    author_id   => $super_author->id,
    authored_on => '2019-08-01',
);

my $edit_content_data1 = 'edit_all_content_data:' . $content_type1->unique_id;
my $edit_content_data2 = 'edit_all_content_data:' . $content_type2->unique_id;

my $edit_content_data1_author = MT::Test::Permission->make_author(
    'name'       => 'edit_cd_1',
    'nickname'   => 'edit_cd_1',
    is_superuser => 0
);
my $edit_content_data2_author = MT::Test::Permission->make_author(
    'name'       => 'edit_cd_2',
    'nickname'   => 'edit_cd_2',
    is_superuser => 0
);

my $edit_content_data1_role = MT::Test::Permission->make_role(
    name        => $edit_content_data1,
    permissions => "'$edit_content_data1'",
);

my $edit_content_data2_role = MT::Test::Permission->make_role(
    name        => $edit_content_data2,
    permissions => "'$edit_content_data2'",
);

MT::Association->link( $edit_content_data1_author, $edit_content_data1_role,
    $blog1 );
MT::Association->link( $edit_content_data2_author, $edit_content_data2_role,
    $blog1 );

subtest 'make_shared_preview' => sub {
    my $type = 'content_data';
    subtest 'Users who can create share previews' => sub {
        subtest 'create_content_data user' => sub {
            subtest 'content_data created by create_content_data user' =>
                sub {
                my $output
                    = SharedPreviewTest::request_make_shared_preview(
                    $create_content_data_author,
                    $blog1->id, $content_data1->id, $type,
                    $content_type1->id );
                ok( $output, 'Output' ) or return;
                SharedPreviewTest::check_response_make_shared_preview(
                    $output, $blog1, $content_data1, $content_type1->id );
                };

            subtest 'content_data created by super user' => sub {
                my $output
                    = SharedPreviewTest::request_make_shared_preview(
                    $create_content_data_author,
                    $blog1->id, $content_data2->id, $type,
                    $content_type1->id );
                ok( $output, 'Output' ) or return;
                SharedPreviewTest::check_response_permission_error($output);
            };
        };

        subtest 'edit_content_data user' => sub {
            my $output
                = SharedPreviewTest::request_make_shared_preview(
                $edit_content_data1_author,
                $blog1->id, $content_data1->id, $type, $content_type1->id );
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_response_make_shared_preview( $output,
                $blog1, $content_data1, $content_type1->id );
        };

        subtest 'super user' => sub {
            my $output = SharedPreviewTest::request_make_shared_preview(
                $super_author, $blog1->id, $content_data1->id,
                $type,         $content_type1->id
            );
            ok( $output, 'Output' ) or return;
            SharedPreviewTest::check_response_make_shared_preview( $output,
                $blog1, $content_data1, $content_type1->id );
        };
    };

    subtest "Users who can't create share previews" => sub {
        my $type   = 'content_data';
        my $output = SharedPreviewTest::request_make_shared_preview(
            $not_permission_author, $blog1->id, $content_data1->id,
            $type,                  $content_type1->id
        );
        ok( $output, 'Output' ) or return;
        SharedPreviewTest::check_response_permission_error($output);
    };

    subtest 'Request parameter check' => sub {
        subtest '_type is empty' => sub {
            my $output = SharedPreviewTest::request_make_shared_preview(
                $super_author, $blog1->id, $content_data1->id,
                '',            $content_type1->id
            );
            ok( $output, 'Output' ) or return;
            like(
                $output,
                qr/Invalid request/,
                'Invalid request error message output.'
            );
        };

        subtest 'id is empty' => sub {
            my $output
                = SharedPreviewTest::request_make_shared_preview(
                $super_author, $blog1->id, '', $type, $content_type1->id );
            ok( $output, 'Output' ) or return;
            like(
                $output,
                qr/Invalid request/,
                'Invalid request error message output.'
            );
        };

        subtest 'content_type_id is empty' => sub {
            my $output
                = SharedPreviewTest::request_make_shared_preview(
                $super_author, $blog1->id, '', $type, '' );
            ok( $output, 'Output' ) or return;
            like(
                $output,
                qr/Invalid request/,
                'Invalid request error message output.'
            );
        };

        subtest 'type is not found' => sub {
            my $output
                = SharedPreviewTest::request_make_shared_preview(
                $super_author,
                $blog1->id, $content_data1->id, 'test_shared_preview',
                $content_type1->id );
            ok( $output, 'Output' ) or return;
            like(
                $output,
                qr/Invalid type: test_shared_preview/,
                'Invalid request error message output.'
            );
        };
    };

    subtest 'shared preview data is found' => sub {
        my $before_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $content_data1->id,
                object_type => 'content_data'
            }
        );

        my $output = SharedPreviewTest::request_make_shared_preview(
            $super_author, $blog1->id, $content_data1->id,
            $type,         $content_type1->id
        );

        ok( $output, 'Output' ) or return;
        SharedPreviewTest::check_response_make_shared_preview( $output,
            $blog1, $content_data1, $content_type1->id );

        my $after_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $content_data1->id,
                object_type => 'content_data'
            }
        );

        is( $before_preview->id, $after_preview->id,
            'Not created a shared preview.' );
    };

    subtest 'shared preview data not found' => sub {
        my $before_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $content_data2->id,
                object_type => 'content_data'
            }
        );

        my $output = SharedPreviewTest::request_make_shared_preview(
            $super_author, $blog1->id, $content_data2->id,
            $type,         $content_type1->id
        );

        ok( $output, 'Output' ) or return;
        SharedPreviewTest::check_response_make_shared_preview( $output,
            $blog1, $content_data2, $content_type1->id );

        my $after_preview = MT->model('preview')->load(
            {   blog_id     => $blog1->id,
                object_id   => $content_data2->id,
                object_type => 'content_data'
            }
        );

        ok( !$before_preview,   'Not created a shared preview.' );
        ok( $after_preview->id, 'Created a new shared preview.' );
    };
};

done_testing;
