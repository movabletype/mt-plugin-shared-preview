package SharedPreviewTest;
use strict;
use warnings;

use Test::More;

use MT;
use MT::Test;
use MT::Preview;

sub check_page_not_found {
    my ($output) = @_;
    like( $output, qr/Status: 404/,    'Status is 404' );
    like( $output, qr/Page Not Found/, 'Page Not Found' );
}

sub check_shared_preview {
    my ( $output, $blog_id, $obj, $spid, $content_type_id ) = @_;
    my $type      = $content_type_id ? 'content_data' : 'entry';
    my $id        = $obj->id;
    my $permalink = MT::Util::encode_html( $obj->permalink );

    like( $output, qr/Status: 200/,         'Status is 200' );
    like( $output, qr/mt-sharedPreviewNav/, 'is shared preview page' );

    my ($edit_link) = $output =~ m/href="(.*)".*(.*id="edit".*)/;
    ok( $edit_link, "$type link" ) or return;

    my $edit_uri = URI->new($edit_link);
    is( $edit_uri->query_param('__mode'),  'view',   'correct mode' );
    is( $edit_uri->query_param('id'),      $id,      'correct id' );
    is( $edit_uri->query_param('blog_id'), $blog_id, 'correct blog_id' );
    is( $edit_uri->query_param('_type'),   $type,    'correct type' );

    if ($content_type_id) {
        is( $edit_uri->query_param('content_type_id'),
            $content_type_id, 'correct content_type_id' );
    }

    my ($shared_preview_link)
        = $output =~ m/.*id="show-preview-url".*data-href="(.*?)"/;
    ok( $shared_preview_link, 'shared preview link' ) or return;

    my $shared_preview_uri = URI->new($shared_preview_link);

    is( $shared_preview_uri->query_param('__mode'),
        'shared_preview', 'correct mode' );
    is( $shared_preview_uri->query_param('spid'), $spid, 'correct spid' );

    my ($permalink_link)
        = $output =~ m/.*id="show-permalink".*data-href="(.*?)"/;

    unless ($content_type_id) {
        ok( $permalink_link, 'shared preview link' ) or return;
        is( $permalink_link, $permalink, 'correct permalink' );
    }
}

sub make_shared_preview {
    my ( $author, $blog_id, $id, $content_type_id ) = @_;

    my %parameters = (
        __test_user             => $author,
        __test_follow_redirects => 1,
        __mode                  => 'make_shared_preview',
        _type                   => 'entry',
        blog_id                 => $blog_id,
        id                      => $id
    );

    if ($content_type_id) {
        $parameters{content_type_id} = $content_type_id;
        $parameters{_type}           = 'content_data';
    }

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my %load_parameters = (
        blog_id     => $blog_id,
        object_id   => $id,
        object_type => $parameters{_type}
    );

    $load_parameters{content_type_id} = $content_type_id if $content_type_id;

    my $preview = MT->model('preview')->load( \%load_parameters );

    return ( $app, $preview->id );
}

sub check_redirect_shared_preview {
    my ( $output, $spid ) = @_;
    my ($location) = $output =~ /Location: (\S+)/;
    my $uri = URI->new($location);
    is( $uri->query_param('__mode'), 'shared_preview', 'correct mode' );
    is( $uri->query_param('spid'),   $spid,            'correct spid' );
}

sub check_response_make_shared_preview {
    my ( $output, $blog, $obj, $content_type_id ) = @_;
    my $preview;

    if ($content_type_id) {
        $preview = MT->model('preview')->load(
            {   blog_id         => $blog->id,
                object_id       => $obj->id,
                object_type     => 'content_data',
                content_type_id => $content_type_id,
            }
        );
    }
    else {
        $preview = MT->model('preview')->load(
            {   blog_id     => $blog->id,
                object_id   => $obj->id,
                object_type => 'entry',
            }
        );
    }

    ok( $preview, 'create shared preview' ) or return;

    my $spid = $preview->id;

    ok( $spid, 'Success in creating shared preview' );
    like( $output, qr/Status: 302 Found/, 'is redirect' );

    like(
        $output,
        qr/Location: .*mt-shared-preview.cgi/,
        'is shared preview url'
    );

    my ($location) = $output =~ /Location: (\S+)/;
    my $uri = URI->new($location);
    is( $uri->query_param('__mode'), 'shared_preview', 'correct mode' );
    is( $uri->query_param('spid'),   $spid,            'correct spid' );
}

sub check_response_permission_error {
    my ($output) = @_;
    like( $output, qr/Status: 200/, 'Status is 200' );
    like(
        $output,
        qr/You attempted to use a feature that you do not have permission to access. If you believe you are seeing this message in error contact your system administrator./,
        'Permission error message output.'
    );
}

sub check_redirect_login {
    my ( $output, $spid ) = @_;
    ok( $output, 'Output' ) or return;
    like( $output, qr/Status: 302 Found/, 'is redirect' );
    like(
        $output,
        qr/Location: .*(__mode=shared_preview_login).*(spid=$spid)/,
        'is shared preview login url'
    );
}

sub request_show_shared_preview {
    my ($spid) = @_;
    my $app = _run_app(
        'MT::App::SharedPreview',
        {   __test_follow_redirects => 1,
            __mode                  => 'shared_preview',
            spid                    => $spid,
        },
    );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub request_make_shared_preview {
    my ( $author, $blog_id, $id, $type, $content_type_id ) = @_;
    my %parameters = (
        __test_user             => $author,
        __test_follow_redirects => 1,
        __mode                  => 'make_shared_preview',
        _type                   => $type,
        blog_id                 => $blog_id,
        id                      => $id
    );

    $parameters{content_type_id} = $content_type_id if $content_type_id;

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my $output = delete $app->{__test_output};
    return $output || '';
}
1;
