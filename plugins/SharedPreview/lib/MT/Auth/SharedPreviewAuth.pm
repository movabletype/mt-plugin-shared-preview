package MT::Auth::SharedPreviewAuth;
use strict;
use warnings;

use MT;
use MT::Preview;
use MT::Serialize;
use MT::Session;
use MT::PluginData;

sub need_login {
    my ( $class, $preview_data ) = @_;

    my $plugin_data = MT::PluginData->load(
        {   plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    return unless $plugin_data;

    return $plugin_data->data->{use_password};

}

sub check_auth {
    my ( $class, $password, $preview_data ) = @_;

    my $plugin_data = MT::PluginData->load(
        {   plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $preview_data->blog_id,
        }
    );

    return unless $plugin_data;

    return $plugin_data->data->{sp_password} =~ /(\Q{\"value\":\"$password\"}\E)/;

}

sub check_session {
    my ( $class, $app, $blog_id ) = @_;

    my $session_id     = get_session_id_from_cookie($app, $blog_id);
    my $session = MT::Session->load($session_id);

    return 0 unless $session;

    return 0 if $session->thaw_data->{blog_id} != $blog_id;

    return $session->thaw_data;

}

sub remove_session {
    my ( $class, $app, $blog_id ) = @_;
    my $session_id     = get_session_id_from_cookie($app, $blog_id);

    MT::Session->remove( { id => $session_id, kind => 'SP' } )
        or return 0;
    1;
}

sub get_session_id_from_cookie {
    my ( $app, $blog_id ) = @_;
    my $cookie_name = 'shared_preview_' . $blog_id;
    my $cookies     = $app->cookies;

    return 0 unless $cookies->{$cookie_name};

    my @cookie_session = split '::', $cookies->{$cookie_name}->{value}[0];

    return 0 unless $cookie_session[1];

    return $cookie_session[1];
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

1;
