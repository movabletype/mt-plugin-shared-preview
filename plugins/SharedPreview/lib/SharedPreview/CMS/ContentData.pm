package SharedPreview::CMS::ContentData;
use strict;
use warnings;

use MT::ContentStatus;
use MT::Preview;
use MT::Template;

sub on_template_param_edit {
    my ( $cb, $app, $param ) = @_;

    my $id              = $app->param('id');
    my $type            = $app->param('_type');
    my $content_type_id = $app->param('content_type_id');

    return unless $id;
    return
        if $param->{status}
        == MT::ContentStatus::RELEASE;    #content_type_unique_id

    my $permission_result
        = MT::Preview->can_create_shared_preview( $app, $app->blog->id,
        $type, $id );
    return '' unless $permission_result;

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

    my $script = MT::Preview::shared_preview_link( $app, $type, $href );

    $script .= MT::Preview::shared_preview_message( $app, $href );

    ( $param->{jq_js_include} ||= '' ) .= $script;
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
    $app->{component} = 'Core';

    my $original_content_data = $app->model($type)->load($id);
    my $content_data          = $original_content_data->clone;

    my $user_id = $app->user ? $app->user->id : 0;
    my @data    = ( { data_name => 'author_id', data_value => $user_id } );
    $app->run_callbacks( 'cms_pre_shared_preview.content_data',
        $app, $content_data, \@data );

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

    my $tmpl;
    if ($tmpl_map) {
        $tmpl = $tmpl_map->template;
        $app->request( 'build_template', $tmpl );
    }
    else {
        $tmpl = $app->load_tmpl('preview_content_data_content.tmpl');
    }

    return $app->errtrans('Cannot load template.')
        unless $tmpl;

    my $ctx  = $tmpl->context;
    my $blog = $app->blog;

    $ctx->stash( 'blog',    $blog );
    $ctx->stash( 'blog_id', $blog->id );

    my $ao_ts = $content_data->authored_on;
    $ao_ts =~ s/\D//g;
    $ctx->{current_timestamp}    = $ao_ts;
    $ctx->{current_archive_type} = $at;
    $ctx->var( 'preview_template', 1 );
    $ctx->stash( 'content',      $content_data );
    $ctx->stash( 'content_type', $content_data->content_type );

    my $archiver = $app->publisher->archiver($at);
    if ( my $params = $archiver->template_params ) {
        $ctx->var( $_, $params->{$_} ) for keys %$params;
    }

    my $html = $tmpl->output;

    my $preview_error;

    unless ( defined $html ) {
        $preview_error = $app->translate( "Publish error: [_1]",
            MT::Util::encode_html( $tmpl->errstr ) );
        my $tmpl_plain = $app->load_tmpl('preview_content_data_content.tmpl');
        $tmpl->text( $tmpl_plain->text );
        $html = $tmpl->output;

        defined($html)
            or return $app->error(
            $app->translate( "Publish error: [_1]", $tmpl->errstr ) );
    }

    my %param = (
        title           => $content_data->label,
        permalink       => MT::Util::encode_html( $content_data->permalink ),
        preview_content => $html,
        preview_error   => $preview_error,
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
