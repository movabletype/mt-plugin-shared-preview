package SharedPreview::CMS::SharedPreview;
use strict;
use warnings;

use MT::App::SharedPreview;
use MT::Preview;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;

sub make_shared_preview {
    my $app = shift;
    my $preview_id;

    my $type = $app->param('_type');
    return $app->errtrans('no type') unless $type;

    my $id = $app->param('id');
    return $app->errtrans('no id') unless $id;

    my $blog_id = $app->blog->id;
    return $app->errtrans('No Blog') unless $blog_id;

    my $obj_class = $app->model($type);
    return $app->errtrans( 'invalid type: [_1]', $type )
        unless $obj_class;

    my $preview = MT::Preview->load(
        {   blog_id     => $blog_id,
            object_type => $type,
            object_id   => $id,
        }
    );

    if ( !$preview ) {
        $preview = MT::Preview->new;
    }

    if ( $type eq 'content_data' ) {
        my $content_type_id = $app->param('content_type_id');
        $preview->content_type_id($content_type_id);
    }

    $preview->blog_id($blog_id);
    $preview->object_id($id);
    $preview->object_type($type);
    $preview->id( $preview->make_unique_id );
    $preview_id = $preview->id;

    $preview->save
        or return $app->errtrans(
        "Could not create share preview link : " . $preview->errstr );

    return $app->redirect(
              $app->app_path
            . $app->config->SharedPreviewScript
            . $app->uri_params(
            mode => 'shared_preview',
            args => { spid => $preview_id },
            )
    );
}

1;
