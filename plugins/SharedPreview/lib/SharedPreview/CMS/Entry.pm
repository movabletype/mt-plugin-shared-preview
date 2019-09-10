package SharedPreview::CMS::Entry;
use strict;
use warnings;

use MT::Entry;
use MT::Preview;
use MT::Util;

sub on_template_param_edit {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $id   = $app->param('id');
    my $type = $app->param('_type');

    return unless $id;
    return if $param->{status} == MT::Entry::RELEASE;

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
            blog_id => $app->blog->id,
            _type   => $type,
            id      => $id,
        },
        );

    my $script = MT::Preview::shared_preview_link( $app, 'entry', $href );
    $script .= MT::Preview::shared_preview_message( $app, $href );

    ( $param->{jq_js_include} ||= '' ) .= $script;

}

sub post_save_entry {
    my ( $cb, $app, $obj, $org_obj ) = @_;
    my $id   = $app->param('id');
    my $type = $app->param('_type');

    return if $obj->status != MT::Entry::RELEASE;

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
    my $id   = $app->param('id');
    my $type = $app->param('_type');

    my $original_entry = $app->model($type)->load($id);
    return $app->errtrans('Invalid request') unless $original_entry;
    my $entry = $original_entry->clone;

    my $user_id = $app->user ? $app->user->id : 0;
    my @data    = ( { data_name => 'author_id', data_value => $user_id } );
    $app->run_callbacks( 'cms_pre_shared_preview.entry',
        $app, $entry, \@data );

    # build entry
    my $at       = $entry->class eq 'page' ? 'Page' : 'Individual';
    my $tmpl_map = $app->model('templatemap')->load(
        {   archive_type => $at,
            blog_id      => $app->blog->id,
            is_preferred => 1,
        }
    );

    my $tmpl;

    if ($tmpl_map) {
        $tmpl = $tmpl_map->template;
        $app->request( 'build_template', $tmpl );
    }
    else {
        $tmpl = $app->load_tmpl('preview_entry_content.tmpl');
    }

    return $app->errtrans('Cannot load template.')
        unless $tmpl;

    my $ctx  = $tmpl->context;
    my $blog = $app->blog;
    $ctx->stash( 'entry',    $entry );
    $ctx->stash( 'blog',     $blog );
    $ctx->stash( 'category', $entry->category );
    my $ao_ts = $entry->authored_on;
    $ao_ts =~ s/\D//g;
    $ctx->{current_timestamp}    = $ao_ts;
    $ctx->{current_archive_type} = $at;
    $ctx->var( 'preview_template', 1 );

    my $archiver = $app->publisher->archiver($at);
    if ( my $params = $archiver->template_params ) {
        $ctx->var( $_, $params->{$_} ) for keys %$params;
    }

    my $html = $tmpl->output;

    my $preview_error;
    unless ( defined($html) ) {
        $preview_error = $app->translate( "Publish error: [_1]",
            MT::Util::encode_html( $tmpl->errstr ) );
        my $tmpl_plain = $app->load_tmpl('preview_entry_content.tmpl');
        $tmpl->text( $tmpl_plain->text );
        $html = $tmpl->output;
        defined($html)
            or return $app->error(
            $app->translate( "Publish error: [_1]", $tmpl->errstr ) );
    }

    my %param = (
        title           => $entry->title,
        permalink       => MT::Util::encode_html( $entry->permalink ),
        preview_content => $html,
        preview_error   => $preview_error,
        edit_uri_params => $app->uri_params(
            mode => 'view',
            args => { blog_id => $app->blog->id, _type => $type, id => $id },
        )
    );

    return \%param;
}

1;

