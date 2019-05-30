package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';

use MT;
use MT::Auth::SharedPreviewAuth;
use MT::Blog;
use MT::Preview;
use MT::Validators::PreviewValidator;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;
use SharedPreview::CMS::SharedPreview;

sub id          {'shared_preview'}
sub script_name { MT->config->SharedPreviewScript }

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview';
}

sub login {
    my $app = shift;

    my $spid = $app->param('spid');
    return $app->error( $app->translate('no id') )
        unless $spid;

    my $preview_data = MT::Preview->load($spid);
    return $app->error( $app->translate('not found : shared preview page.') )
        unless $preview_data;

    return load_login_form( $app, $spid ) if $app->request_method eq 'GET';

    my $password = $app->param('password');
    return load_login_form( $app, $spid, $app->translate('no password') )
        unless $password;

    my $check_result
        = MT::Auth::SharedPreviewAuth->check_auth( $password, $preview_data );
    return load_login_form( $app, $spid,
        $app->translate('Passwords do not match.') )
        unless $check_result;

    my $start_session_result
        = MT::Auth::SharedPreviewAuth::start_session( $app,
        $preview_data->blog_id, $password );
    return load_login_form( $app, $spid, $start_session_result )
        if $start_session_result;

    return $app->redirect(
        $app->uri(
            mode => 'shared_preview',
            args => { spid => $spid },
        )
    );

}

sub shared_preview {
    my $app    = shift;
    my $result = MT::Validators::PreviewValidator->view_validator($app);
    return $app->error($result) if defined $result;
    my $preview_id   = $app->param('spid');
    my $preview_data = MT::Preview->load($preview_id);

    my $need_login = MT::Auth::SharedPreviewAuth->need_login($preview_data);

    if ($need_login) {
        my $check_session_result
            = MT::Auth::SharedPreviewAuth->check_session( $app,
            $preview_data->blog_id );

        return $app->redirect(
            $app->uri(
                mode => 'shared_preview_login',
                args => { spid => $preview_id },
            )
        ) unless $check_session_result;

        my $check_auth_result
            = MT::Auth::SharedPreviewAuth->check_auth(
            $check_session_result->{password},
            $preview_data );

        unless ($check_auth_result) {
            MT::Auth::SharedPreviewAuth->remove_session( $app,
                $preview_data->blog_id );
            return $app->redirect(
                $app->uri(
                    mode => 'shared_preview_login',
                    args => { spid => $preview_id },
                )
            );
        }
    }

    set_app_parameters( $app, $preview_data );

    my $param;
    my $type = $app->param('_type');

    if ( $type eq 'entry' || $type eq 'page' ) {
        $param = SharedPreview::CMS::Entry->build_preview($app);
    }
    else {
        $param = SharedPreview::CMS::ContentData->build_preview($app);
    }

    return unless defined $param;

    $param->{back_edit}
        = $app->app_path
        . MT->config->AdminScript
        . $param->{edit_uri_params};
    $param->{spid} = $preview_id;

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
        $app->param( 'content_type_id', $preview->content_type_id );
    }
}

sub load_login_form {
    my ( $app, $preview_id, $error ) = @_;
    my $site_name;
    my $site_url;
    if ($preview_id) {
        my $site;
        my $preview_data = MT::Preview->load($preview_id);
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
