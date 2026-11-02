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
    return $app->errtrans('Invalid request') unless $type;

    my $id = $app->param('id');
    return $app->errtrans('Invalid request') unless $id;

    my $blog_id = $app->blog->id;
    return $app->errtrans('Invalid request') unless $blog_id;

    return $app->errtrans( 'Invalid type: [_1]', $type )
        unless grep { $type eq $_ } qw( entry page content_data );

    my $obj = $app->model($type)->load({ id => $id, blog_id => $blog_id });
    return $app->errtrans('Invalid request') unless $obj;

    my $permission_result
        = MT::Preview->can_create_shared_preview( $app, $blog_id, $type,
        $id );

    return $app->permission_denied unless $permission_result;

    my $preview = MT::Preview->load(
        {   blog_id     => $blog_id,
            object_type => $type,
            object_id   => $id,
        }
    );

    if ( !$preview ) {
        $preview = MT::Preview->new;
        if ( $type eq 'content_data' ) {
            my $content_type_id = $app->param('content_type_id');
            $preview->content_type_id($content_type_id);
        }

        $preview->blog_id($blog_id);
        $preview->object_id($id);
        $preview->object_type($type);
        $preview->id( $preview->make_unique_id );

        $preview->save
            or return $app->errtrans(
            "Could not create shared preview link: [_1]",
            $preview->errstr );
    }

    $preview_id = $preview->id;

    return $app->redirect(
              $app->app_path
            . $app->config->SharedPreviewScript
            . $app->uri_params(
            mode => 'shared_preview',
            args => { spid => $preview_id },
            )
    );
}

sub config_template {
    my ( $plugin, $param, $scope ) = @_;

    if ( !$param->{'sp_password[]'} ) {
        $param->{'sp_password[]'} = [""];
    }
    elsif ( !ref $param->{'sp_password[]'} ) {
        $param->{'sp_password[]'} = [ $param->{'sp_password[]'} ];
    }

    $plugin->load_tmpl( 'shared_preview_setting.tmpl', $param );
}

1;
