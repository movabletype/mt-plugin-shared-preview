package MT::Validators::SharedPreviewAuthValidator;
use strict;
use warnings;

use MT::Preview;

sub login_validate {
    my ( $self, $app ) = @_;
    my %password_validate = &password_validate(@_);
    return %password_validate if $password_validate{'error'};

    my %spid_validate = &spid_validate(@_);
    return %spid_validate if $spid_validate{'error'};

    return (
        password => $password_validate{'value'},
        spid     => $spid_validate{'value'},
    );
}

sub password_validate {
    my ( $self, $app ) = @_;
    my $password = $app->param('password');
    my $message  = $app->translate('no password') unless $password;
    return (
        error   => $message || 0,
        message => $message,
        value   => $password
    );
}

sub spid_validate {
    my ( $self, $app ) = @_;
    my $spid    = $app->param('spid');
    my $message = $app->translate('no id') unless $spid;

    return (
        error   => $message || 0,
        message => $message,
        value   => $spid
    );
}

1;
