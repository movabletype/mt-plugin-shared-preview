package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';

use MT;
use MT::Auth::SharedPreviewAuth;
use MT::Blog;
use MT::Preview;
use MT::Session;
use MT::SharedPreviewPluginData;
use MT::Validators::PreviewValidator;
use MT::Validators::SharedPreviewAuthValidator;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;
use SharedPreview::CMS::SharedPreview;

sub id          {'shared_preview'}
sub script_name { MT->config->SharedPreviewScript }

sub ERROR_PASSWORD {1}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview';
}

sub login {
    my $app  = shift;
    my $spid = $app->param('spid');

    my %validate
        = MT::Validators::SharedPreviewAuthValidator->login_validate($app);
    return load_login_form( $app, $spid, $validate{message} )
        if $validate{error};

    my $preview_data = MT::Preview->get_preview_data_by_id( $validate{spid} );
    return $app->error( $app->translate('not found Shared Preview page.') )
        unless $preview_data;

    my $check_result = MT::Auth::SharedPreviewAuth->check_auth( \%validate );
    return load_login_form( $app, $validate{spid},
        $app->translate('Passwords do not match.') )
        unless $check_result;

    my $start_session_result = start_session( $app, $preview_data->blog_id );
    return load_login_form( $app, $validate{spid}, $start_session_result )
        unless $check_result;

    return $app->redirect(
        $app->uri(
            mode => 'shared_preview',
            args => { spid => $validate{spid} },
        )
    );
}

sub login_form {
    my $app = shift;
    my %validate
        = MT::Validators::SharedPreviewAuthValidator->spid_validate($app);
    return $app->error( $validate{message} ) if $validate{error};

    my $preview_data
        = MT::Preview->get_preview_data_by_id( $validate{value} );
    return $app->error( $app->translate('not found : shared preview page.') )
        unless $preview_data;

    return load_login_form( $app, $validate{value} );
}

sub make_session {
    my ( $app, $blog_id ) = @_;
    my $session = MT::Session->new;

    $session->id( $app->make_magic_token() );
    $session->kind('SP');
    $session->start(time);
    $session->name('shared_preview');
    $session->set( 'blog_id', $blog_id );
    $session->save;

    return $session;

}

sub set_save_values {
    my $preview_obj = shift;
    my ($set_data)  = @_;
    my $data        = {};

    for my $column ( @{ $set_data || [] } ) {
        my $column_name = $column->{object_name};
        if ( $column_name eq 'data' ) {
            $data->{ $column->{data_name} } = $column->{data_value};
        }
        elsif ($column_name) {
            $preview_obj->$column_name( $column->{data_value} );
        }
    }

    if ($data) {
        $preview_obj->data($data);
    }

    $preview_obj->id( $preview_obj->make_unique_id );
    $preview_obj->{__dirty} = 1;
}

sub start_session {
    my ( $app, $blog_id ) = @_;

    my $make_session = make_session(@_);
    return $make_session->errstr if $make_session->errstr;

    my %arg = (
        -name  => 'shared_preview_' . $blog_id,
        -value => Encode::encode(
            $app->charset, join( '::', 'shared_preview', $make_session->id )
        ),
        -path    => $app->config->CookiePath || $app->mt_path,
        -expires => '+3M',
    );

    $app->bake_cookie(%arg);

    return '';

}

sub shared_preview {
    my $app    = shift;
    my $result = MT::Validators::PreviewValidator->view_validator($app);
    return $app->error($result) if defined $result;
    my $preview_id   = $app->param('spid');
    my $preview_data = MT::Preview->get_preview_data_by_id($preview_id);

    my $need_login = MT::Auth::SharedPreviewAuth->need_login($preview_id);

    if ($need_login) {
        my $check_auth_result
            = MT::Auth::SharedPreviewAuth->check_session( $app,
            $preview_data->blog_id );

        return $app->redirect(
            $app->uri(
                mode => 'shared_preview_login',
                args => { spid => $preview_id },
            )
        ) unless $check_auth_result;
    }

    set_app_parameters( $app, $preview_data );

    my $param;
    my $type = $app->param('_type');

    if ( $type eq 'entry' || $type eq 'page' ) {
        $param = SharedPreview::CMS::Entry->_build_preview($app);
    }
    else {
        $param = SharedPreview::CMS::ContentData->_build_preview($app);
    }

    return unless defined $param;
    $param->{back_edit} = $app->app_path . MT->config->AdminScript;
    $param->{spid}      = $preview_id;

    my $site;
    $site = MT::Blog->load( $preview_data->blog_id )
        if $preview_data->blog_id;

    if ($site) {
        $param->{site_name} = $site->name     if $site;
        $param->{site_url}  = $site->site_url if $site;
    }

    return $app->component('SharedPreview')
        ->load_tmpl( 'shared_preview_strip.tmpl', $param );

}

sub set_app_parameters {
    my ( $app, $preview ) = @_;
    $app->param( 'id',      $preview->object_id );
    $app->param( '_type',   $preview->object_type );
    $app->param( 'blog_id', $preview->blog_id );

    if ( $preview->object_type eq 'content_data' ) {
        $app->param( 'content_type_id', $preview->data->{content_type_id} );
    }
}

sub load_login_form {
    my ( $app, $preview_id, $error ) = @_;
    my $site_name;
    my $site_url;
    if ($preview_id) {
        my $site;
        my $preview_data = MT::Preview->get_preview_data_by_id($preview_id);
        $site = MT::Blog->load( $preview_data->blog_id )
            if $preview_data->blog_id;
        $site_name = $site->name     if $site;
        $site_url  = $site->site_url if $site;
    }

    return $app->component('SharedPreview')->load_tmpl(
        'shared_preview_login.tmpl',
        {   query_params => [
                {   name  => 'spid',
                    value => $preview_id,
                },
                {   name  => '__mode',
                    value => 'shared_preview_auth',
                },
            ],
            site_name => $site_name,
            site_url  => $site_url,
            error     => $error
        }
    );
}

1;
