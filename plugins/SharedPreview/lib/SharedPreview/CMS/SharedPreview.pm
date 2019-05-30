package SharedPreview::CMS::SharedPreview;
use strict;
use warnings;

use MT::App::SharedPreview;
use MT::Preview;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;

sub make_shared_preview {
    my $app = shift;
    my $created_id;

    my $type = $app->param('_type');
    return $app->error( $app->translate('no type') ) unless $type;

    my $id = $app->param('id');
    return $app->error( $app->translate('no id') ) unless $id;

    my $blog_id = $app->blog->id;
    return $app->error( $app->translate('No Blog') ) unless $blog_id;

    my $obj_class = $app->model($type);
    return $app->error( $app->translate( 'invalid type: [_1]', $type ) )
        unless $obj_class;

    my $preview_obj = MT::Preview->new;

    if (my $preview = MT::Preview->load(
            {   blog_id     => $blog_id,
                object_type => $type,
                object_id   => $id,
            }
        )
        )
    {
        $created_id = $preview->id;
    }
    else {

        if ( $type eq 'content_data' ) {
            my $content_type_id = $app->param('content_type_id');
            $preview_obj->content_type_id($content_type_id);
        }

        $preview_obj->blog_id($blog_id);
        $preview_obj->object_id($id);
        $preview_obj->object_type($type);
        $preview_obj->id( $preview_obj->make_unique_id );
        $created_id = $preview_obj->id;

        $preview_obj->save
            or $app->error(
            "Could not create share preview link : " . $preview_obj->errstr );

    }

    return $app->redirect(
              $app->app_path
            . $app->config->SharedPreviewScript
            . $app->uri_params(
            mode => 'shared_preview',
            args => { spid => $created_id },
            )
    );
}

1;
