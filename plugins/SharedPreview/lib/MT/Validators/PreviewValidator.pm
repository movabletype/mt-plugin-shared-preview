package MT::Validators::PreviewValidator;
use strict;
use warnings;

use MT::Preview;

sub make_validator {
    my ( $self, $app ) = @_;

    my $blog = $app->blog;
    return $app->translate('No Blog') unless $blog;

    my $type = $app->param('_type');
    return $app->translate('no type') unless $type;

    my $obj_class = $app->model($type);
    return $app->translate( 'invalid type: [_1]', $type ) unless $obj_class;

    my $id = $app->param('id');
    return $app->translate('no id') unless $id;

    return undef;
}

sub view_validator {
    my ( $self, $app ) = @_;
    my $spid = $app->param('spid');
    return $app->translate('no id') unless $spid;

    my $preview = MT::Preview->load($spid);
    return $app->translate('There is no shared preview') unless $preview;

    return undef;
}
1;
