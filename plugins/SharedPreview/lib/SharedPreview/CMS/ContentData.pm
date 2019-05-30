package SharedPreview::CMS::ContentData;
use strict;
use warnings;

use MT::ContentStatus;
use MT::Preview;

sub on_template_param_edit {
    my ( $cb, $app, $param ) = @_;

    my $id              = $app->param('id');
    my $type            = $app->param('_type');
    my $content_type_id = $app->param('content_type_id');

    my $href
        = $app->app_path
        . $app->config->AdminScript
        . $app->uri_params(
        mode => 'make_shared_preview',
        args => {
            blog_id         => $app->blog->id,
            _type           => $type,
            id              => $id,
            content_type_id => $content_type_id,
        },
        );

    my $add_link = '';
    $add_link = MT::Preview->add_shared_preview_link( $type, $href )
        if $param->{status} != MT::ContentStatus::RELEASE;

    ( $param->{jq_js_include} ||= '' ) .= $add_link;
}

sub post_save_content_data {
    my ( $cb, $app, $obj, $org_obj ) = @_;
    my $id   = $app->param('id');
    my $type = $app->param('_type');

    return if $obj->status != MT::ContentStatus::RELEASE;

    if (my $preview = MT::Preview->load(
            {   blog_id     => $app->blog->id,
                object_type => $type,
                object_id   => $id,
            }
        )
        )
    {
        $preview->remove;
    }

    1;
}

sub build_preview {
    my ( $class, $app ) = @_;
    my $at              = 'ContentType';
    my $content_type_id = $app->param('content_type_id');
    my $id              = $app->param('id');
    my $type            = $app->param('_type');

    my $content_data = $app->model($type)->load($id);

    # build entry
    my $tmpl_map = $app->model('templatemap')->load(
        {   archive_type => $at,
            blog_id      => $app->blog->id,
            is_preferred => 1,

        },
        {   join => MT::Template->join_on(
                undef,
                {   id              => \'= templatemap_template_id',
                    content_type_id => $content_type_id,
                },
            ),
        },
    );

    my $fullscreen;
    my $tmpl;
    if ($tmpl_map) {
        $tmpl = $tmpl_map->template;
        $app->request( 'build_template', $tmpl );
    }
    else {
        # TODO
        $fullscreen = 1;
    }
    return $app->errtrans('Cannot load template.')
        unless $tmpl;

    my $ctx  = $tmpl->context;
    my $blog = $app->blog;
    $ctx->stash( 'content_data', $content_data );
    $ctx->stash( 'blog',         $blog );

    my $ao_ts = $content_data->authored_on;
    $ao_ts =~ s/\D//g;
    $ctx->{current_timestamp}    = $ao_ts;
    $ctx->{current_archive_type} = $at;
    $ctx->var( 'preview_template', 1 );

    my $archiver = $app->publisher->archiver($at);
    if ( my $params = $archiver->template_params ) {
        $ctx->var( $_, $params->{$_} ) for keys %$params;
    }

    my $html = $tmpl->output;
    return unless defined $html;

    my %param = (
        preview_content => $html,
        title           => $content_data->label,
        permalink       => MT::Util::encode_html( $content_data->permalink ),
        edit_uri_params => $app->uri_params(
            mode => 'view',
            args => {
                blog_id         => $app->blog->id,
                _type           => $type,
                id              => $id,
                content_type_id => $content_type_id
            },
        )
    );

    return \%param;
}

1;
