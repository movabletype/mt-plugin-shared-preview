package SharedPreview::CMS::SharedPreview;
use strict;
use warnings;

use base qw(SharedPreview::CMS::SharedPreviewBase);

use MT::App::SharedPreview;
use MT::Preview;
use MT::Validators::PreviewValidator;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;

sub make_shared_preview {
    my $app = shift;
    my @params;
    my $result = MT::Validators::PreviewValidator->make_validator($app);
    return $app->error($result) if defined $result;

    my $type    = $app->param('_type');
    my $id      = $app->param('id');
    my $blog_id = $app->blog->id;
    my $created_id;

    if ( $type eq 'content_data' ) {
        @params = SharedPreview::CMS::ContentData::trim_parameter($app);
    }
    else {
        @params = SharedPreview::CMS::Entry::trim_parameter($app);
    }

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
        MT::App::SharedPreview::set_save_values( $preview_obj, \@params );
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
