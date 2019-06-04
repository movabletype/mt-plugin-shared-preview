package SharedPreview::Auth;
use strict;
use warnings;

use MT;
use MT::Preview;
use MT::Serialize;
use MT::Session;
use MT::PluginData;

sub need_login {
    my ($plugin_data) = @_;

    return unless $plugin_data;

    return $plugin_data->data->{use_password};
}

sub check_auth {
    my ( $password, $plugin_data ) = @_;

    return unless $plugin_data;

    require JSON;
    my $sp_password = $plugin_data->data->{sp_password};

    my $decode_outside = JSON::decode_json($sp_password);
    my $password_list  = JSON::decode_json($decode_outside);

    for my $password_config (@$password_list) {
        return 1 if $password_config->{value} eq $password;
    }
}

sub check_session {
    my ( $app, $blog_id ) = @_;

    my $session_id = get_session_id_from_cookie( $app, $blog_id );
    return unless $session_id;

    my $session = MT::Session->load($session_id);
    unless ($session) {
        remove_cookie( $app, $blog_id );
        return;
    }

    if ( $session->thaw_data->{blog_id} != $blog_id ) {
        remove_session( $app, $blog_id );
        return;
    }

    return $session->thaw_data;

}

sub remove_session {
    my ( $app, $blog_id ) = @_;
    my $session_id = get_session_id_from_cookie( $app, $blog_id );
    return unless $session_id;

    remove_cookie( $app, $blog_id );

    MT::Session->remove( { id => $session_id, kind => 'SP' } );
}

sub get_session_id_from_cookie {
    my ( $app, $blog_id ) = @_;
    my $cookie_name = 'shared_preview_' . $blog_id;
    my $cookies     = $app->cookies;

    return unless $cookies->{$cookie_name};
    return unless $cookies->{$cookie_name}->{value}[0];

    return $cookies->{$cookie_name}->{value}[0];
}

sub make_session {
    my ( $app, $blog_id, $password ) = @_;
    my $session = MT::Session->new;

    $session->id( $app->make_magic_token() );
    $session->kind('SP');
    $session->start(time);
    $session->name('shared_preview');
    $session->set( 'blog_id',  $blog_id );
    $session->set( 'password', $password );
    $session->save;

    return $session;

}

sub start_session {
    my ( $app, $blog_id, $password ) = @_;

    my $make_session = make_session( $app, $blog_id, $password );
    return $make_session->errstr if $make_session->errstr;

    my %arg = (
        -name    => 'shared_preview_' . $blog_id,
        -value   => $make_session->id,
        -path    => $app->config->CookiePath || $app->mt_path,
        -expires => '+3M',
    );

    $app->bake_cookie(%arg);

    return '';

}

sub remove_cookie {
    my ( $app, $blog_id ) = @_;

    my %arg = (
        -name    => 'shared_preview_' . $blog_id,
        -value   => '',
        -path    => $app->config->CookiePath || $app->mt_path,
        -expires => '-1y',
    );

    $app->bake_cookie(%arg);
}

1;
