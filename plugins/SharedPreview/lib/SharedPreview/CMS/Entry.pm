package SharedPreview::CMS::Entry;
use strict;
use warnings;

use base qw(SharedPreview::CMS::SharedPreviewBase);

sub on_template_param_edit {
    my ( $cb, $app, $param, $tmpl ) = @_;
    return unless my $base = SharedPreview::CMS::SharedPreviewBase->new($app);

    my $id = $app->param('id');
    my $type = $app->param('_type');
    my $href = $app->uri_params(
        mode => 'dialog_shared_preview',
        args => {
            blog_id         => $app->blog->id,
            _type           => $type,
            id              => $id,
            dialog          => 1,
        },
    );

    ($param->{jq_js_include} ||= '')
        .= $base->add_shared_preview_link($href);
}

sub _build_preview {
    my ($class, $app) = @_;
    my $id = $app->param('id');
    my $type = $app->param('_type');

    my $entry = $app->model($type)->load($id);
    return $app->errtrans( 'invalid id: [_1]', $id ) unless $entry;

    # build entry
    my $at       = $entry->class eq 'page' ? 'Page' : 'Individual';
    my $tmpl_map = $app->model('templatemap')->load(
        {   archive_type => $at,
            blog_id      => $app->blog->id,
            is_preferred => 1,
        }
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

    my @inputs  = (
        {
            data_name  => 'id',
            data_value => $id,
        },
        {
            data_name  => '_type',
            data_value => $type,
        },
        {
            data_name  => 'blog_id',
            data_value => $app->blog->id,
        },
    );

    my $html = $tmpl->output;
    my %param = (
        id              => $id,
        object_type     => $type,
        preview_content => $html,
        title           => $entry->title,
        inputs          => \@inputs
    );

    return \%param;
}

1;

