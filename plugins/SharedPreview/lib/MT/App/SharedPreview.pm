package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';

use MT;
use MT::Serialize;

sub id          {'shared_preview'}
sub script_name { MT->config->SharedPreviewScript }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods( shared_preview => \&shared_preview );
    return $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview';
}

sub shared_preview {
    my $app = shift;

    my $blog = $app->blog;
    return $app->errtrans('no blog') unless $blog;

    my $type = $app->param('_type');
    return $app->errtrans('no type') unless $type;

    my $obj_class = $app->model($type);
    return $app->errtrans( 'invalid type: [_1]', $type ) unless $obj_class;

    my $id = $app->param('id');
    return $app->errtrans('no id') unless $id;

    my $entry = $app->model($type)->load($id);
    return $app->errtrans( 'invalid id: [_1]', $id ) unless $entry;

    my $html = $app->_build_preview_entry($entry);
    return unless defined $html;

    my %param = (
        id              => $id,
        object_type     => $type,
        preview_content => $html,
        title           => $entry->title,
    );
    return $app->component('SharedPreview')
        ->load_tmpl( 'shared_preview_strip.tmpl', \%param );
}

sub _build_preview_entry {
    my $app = shift;
    my ($entry) = @_;

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

    $tmpl->output;
}

1;

