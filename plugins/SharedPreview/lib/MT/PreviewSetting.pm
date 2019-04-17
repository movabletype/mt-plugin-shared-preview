# Movable Type (r) (C) 2001-2019 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::PreviewSetting;
use strict;
use warnings;

use MT::Object;
@MT::PreviewSetting::ISA = qw( MT::Object );

use MT::Util qw( dirify );

__PACKAGE__->install_properties(
    {
        column_defs =>
            {
                'id'       => 'string(40) not null',
                'blog_id'  => 'integer(11)',
                'use_password' => 'smallint not null',
                'password' => 'string(255)',
            },
        indexes => {
            setting_tag => { columns => [ 'blog_id'], },
        },
        primary_key => 'id',
        datasource  => 'preview_setting',
    }
);

sub class_label {
    return MT->translate("PreviewSetting");
}

sub save {
    my $self = shift;
    if ( my $data = $self->{__data} ) {
        require MT::Serialize;
        my $ser = MT::Serialize->serialize( \$data );
        $self->data($ser);
    }
    $self->{__dirty} = 0;
    $self->SUPER::save(@_);
}

sub make_unique_id {
    my $self = shift;
    my %param = @_;
    my ( $blog_id, $object_id, $object_type)
        = @param{qw( blog_id object_id object_type )};

    return time;
}

sub thaw_data {
    my $self = shift;
    return $self->{__data} if $self->{__data};
    my $data = $self->data;
    $data = '' unless $data;
    require MT::Serialize;
    my $out = MT::Serialize->unserialize($data);
    if ( ref $out eq 'REF' ) {
        $self->{__data} = $$out;
    }
    else {
        $self->{__data} = {};
    }
    $self->{__dirty} = 0;
    $self->{__data};
}

sub get {
    my $self  = shift;
    my ($var) = @_;
    my $data  = $self->thaw_data;
    $data->{$var};
}

sub purge {
    my $class = shift;
    my ( $kind, $ttl ) = @_;

    $class = ref($class) if ref($class);

    my $terms = { $kind ? ( kind => $kind ) : () };
    my $args = {};
    if ($ttl) {
        $terms->{start} = [ undef, time - $ttl ];
        $args->{range} = { start => 1 };
    }
    else {
        # use stored expiration period
        $terms->{duration} = [ undef, time ];
        $args->{range} = { duration => 1 };
    }

    $class->remove( $terms, $args )
        or return $class->error( $class->errstr );
    1;
}

1;

