package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';

use MT;
use SharedPreview::Auth;
use MT::Blog;
use MT::Preview;
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

    my $preview_id = $app->param('spid');
    return page_not_found($app)
        unless MT::Preview::validate_preview_id($preview_id);

    my $preview_data = MT::Preview->load($preview_id);
    return page_not_found($app) unless $preview_data;

    my $site = MT::Blog->load( $preview_data->blog_id );
    return page_not_found($app) unless $site;

    my $plugin_data = MT::PluginData->load(
        {   plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    my @uri = (
        mode => 'shared_preview',
        args => { spid => $preview_id }
    );

    my $need_login = SharedPreview::Auth::need_login($plugin_data);
    return $app->redirect( $app->uri(@uri) ) unless $need_login;

    $app->set_language( $site->language );

    return load_login_form( $app, $preview_data, $site )
        if $app->request_method ne 'POST';

    my $password = $app->param('password');
    return load_login_form( $app, $preview_data,
        $site, $app->translate('You must supply a password.') )
        unless $password;

    my $check_result
        = SharedPreview::Auth::check_auth( $password, $plugin_data );
    return load_login_form( $app, $preview_data, $site,
        $app->translate('Passwords do not match.') )
        unless $check_result;

    my $remember = $app->param('sp_remember');

    my $start_session_result
        = SharedPreview::Auth::start_session( $app,
        $preview_data->blog_id, $password, $remember );
    return load_login_form( $app, $preview_data, $site,
        $start_session_result )
        if $start_session_result;

    return $app->redirect( $app->uri(@uri) );

}

sub shared_preview {
    my $app = shift;

    my $preview_id = $app->param('spid');
    return page_not_found($app)
        unless MT::Preview::validate_preview_id($preview_id);

    my $preview_data = MT::Preview->load($preview_id);
    return page_not_found($app) unless $preview_data;

    my $site = MT::Blog->load( $preview_data->blog_id );
    return page_not_found($app) unless $site;

    $app->set_language( $site->language );

    my $plugin_data = MT::PluginData->load(
        {   plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    my $need_login = SharedPreview::Auth::need_login($plugin_data);

    if ($need_login) {
        my $check_session_result
            = SharedPreview::Auth::check_session( $app,
            $preview_data->blog_id );

        return $app->redirect(
            $app->uri(
                mode => 'shared_preview_login',
                args => { spid => $preview_id },
            )
        ) unless $check_session_result;

        my $check_auth_result
            = SharedPreview::Auth::check_auth(
            $check_session_result->{password}, $plugin_data );

        unless ($check_auth_result) {
            SharedPreview::Auth::remove_session( $app,
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
    $param->{spid}      = $preview_id;
    $param->{site_name} = $site->name;
    $param->{site_url}  = $site->site_url;
    $param->{preview_content}
        = $app->translate_templatized( $param->{preview_content} );
    $param->{mt_static_shared_preview}
        = $app->static_path . 'plugins/SharedPreview/';

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
    my ( $app, $preview_data, $site, $error ) = @_;
    $app->response_code(401);

    return $app->component('SharedPreview')->load_tmpl(
        'shared_preview_login.tmpl',
        {   shared_preview_params => [
                {   name  => 'spid',
                    value => $preview_data->id,
                },
                {   name  => '__mode',
                    value => 'shared_preview_login',
                },
            ],
            site_name => $site->name,
            site_url  => $site->site_url,
            error     => $error
        }
    );
}

sub page_not_found {
    my $app = shift;
    $app->response_code(404);
    return $app->error( $app->translate('Page Not Found') );
}

1;
