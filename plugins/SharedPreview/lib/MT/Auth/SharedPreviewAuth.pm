package MT::Auth::SharedPreviewAuth;
use strict;
use warnings;

use MT;
use MT::Preview;
use MT::Serialize;
use MT::Session;

sub need_login {
    my ( $app, $preview_id ) = @_;

    my $preview_data = MT::Preview->get_preview_data_by_id($preview_id);
    return undef unless $preview_data;

    my $plugin_data = MT::PluginData->load(
        {
            plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    return undef unless $plugin_data;

    return 1
      if $plugin_data->data->{use_password} == MT::Preview::USE_PASSWORD_VALID;

}

sub check_auth {
    my ( $self, $parameters ) = @_;

    my $preview_data =
      MT::Preview->get_preview_data_by_id( $parameters->{spid} );
    return undef unless $preview_data;

    my $plugin_data = MT::PluginData->load(
        {
            plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    return $plugin_data->data->{password} eq $parameters->{password};

}

sub check_session {
    my ( $self, $app, $blog_id ) = @_;
    my $cookie_name = 'shared_preview_' . $blog_id;
    my $cookies     = $app->cookies;

    return 0 unless $cookies->{$cookie_name};

    my @cookie_session = split '::', $cookies->{$cookie_name}->{value}[0];
    my $session_id     = $cookie_session[1];

    my $session = MT::Session->load($session_id);

    return 0 unless $session;

    return $session->thaw_data->{blog_id} == $blog_id;

}

1;