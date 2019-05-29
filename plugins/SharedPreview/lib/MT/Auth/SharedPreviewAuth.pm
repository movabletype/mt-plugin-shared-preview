package MT::Auth::SharedPreviewAuth;
use strict;
use warnings;

use MT;
use MT::Preview;
use MT::Serialize;
use MT::Session;
use MT::PluginData;

sub need_login {
    my ( $app, $preview_id ) = @_;

    my $preview_data = MT::Preview->load($preview_id);

    return unless $preview_data;

    my $plugin_data = MT::PluginData->load(
        {
            plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    return unless $plugin_data;

    return $plugin_data->data->{use_password};

}

sub check_auth {
    my ( $self, $parameters ) = @_;

    my $preview_data = MT::Preview->load($parameters->{spid});
    return unless $preview_data;

    my $plugin_data = MT::PluginData->load(
        {
            plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    return $plugin_data->data->{sp_password} =~ /(\Q{\"value\":\"$parameters->{sp_password}\"}\E)/;

}

sub check_session {
    my ( $self, $app, $blog_id ) = @_;

    my $session_id     = get_session_id_from_cookie(@_);
    my $session = MT::Session->load($session_id);

    return 0 unless $session;

    return 0 if $session->thaw_data->{blog_id} != $blog_id;

    return $session->thaw_data;

}

sub remove_session {
    my ( $self, $app, $blog_id ) = @_;

    my $session_id     = get_session_id_from_cookie(@_);

    MT::Session->remove( { id => $session_id, kind => 'SP' } )
        or return 0;
    1;
}

sub get_session_id_from_cookie {
    my ( $self, $app, $blog_id ) = @_;
    my $cookie_name = 'shared_preview_' . $blog_id;
    my $cookies     = $app->cookies;

    return 0 unless $cookies->{$cookie_name};

    my @cookie_session = split '::', $cookies->{$cookie_name}->{value}[0];

    return 0 unless $cookie_session[1];

    return $cookie_session[1];
}

1;
