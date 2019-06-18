package SharedPreview::CMS::ContentData;
use strict;
use warnings;

use MT::ContentStatus;
use MT::Preview;
use MT::Template;
eval { use IPC::Run3 'run3' };

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

    my $has_template;
    my $tmpl;
    if ($tmpl_map) {
        $tmpl = $tmpl_map->template;
        $app->request( 'build_template', $tmpl );
        $has_template = 1;
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

    if ($has_template) {
        $ctx->stash( 'content_data', $content_data );
    }
    else {
        $ctx->stash( 'content',      $content_data );
        $ctx->stash( 'content_type', $content_data->content_type );
    }

    my $archiver = $app->publisher->archiver($at);
    if ( my $params = $archiver->template_params ) {
        $ctx->var( $_, $params->{$_} ) for keys %$params;
    }

    my $html;
    $html = $tmpl->output;

    unless ($has_template) {
        $html = $tmpl->text( $app->translate_templatized($html) ) if $html;
    }

    return unless defined $html;

    my $script_result;
    my $error;
    my $script = $tmpl->text;
    my $has_php = &has_php;

    if ($has_php) {
        run3 [ 'php', '-q' ], \$script, \$script_result, $error;
    }

    $html = $script_result unless $error;

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

sub has_php {
    my $HasPHP;
    my $php_version_string = `php --version 2>&1` or return $HasPHP = 0;
    my ($php_version) = $php_version_string =~ /^PHP (\d+\.\d+)/i;
    $HasPHP = ( $php_version and $php_version >= 5 ) ? 1 : 0;
    if (MT->config->ObjectDriver =~ /u?mssqlserver/i) {
        my $phpinfo = `php -i 2>&1` or return $HasPHP = 0;
        $HasPHP = 0 if $phpinfo =~ /\-\-without\-(?:pdo\-)?mssql/;
    }
    $HasPHP;
}

1;
