# Movable Type (r) (C) 2001-2019 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::Preview;
use strict;
use warnings;

use MT::Object;
@MT::Preview::ISA = qw( MT::Object );

use MT::Util qw( dirify );

__PACKAGE__->install_properties(
    {
        column_defs =>
            {
                'id'          => 'string(40) not null',
                'object_id'     => 'integer not null',
                'object_type'        => 'string(50) not null',
                'blog_id' => 'integer(11)',
            },
        indexes => {
            blog_tag => { columns => [ 'blog_id', 'object_type', 'object_id'], },
        },
        primary_key => 'id',
        datasource  => 'preview',
    }
);

sub class_label {
    return MT->translate("Preview");
}

sub save {
    my $sess = shift;
    if ( my $data = $sess->{__data} ) {
        require MT::Serialize;
        my $ser = MT::Serialize->serialize( \$data );
        $sess->data($ser);
    }
    $sess->{__dirty} = 0;
    $sess->SUPER::save(@_);
}


sub make_unique_id {
    my $field = shift;
    my %param = @_;
    my ( $blog_id, $object_id, $object_type)
        = @param{qw( blog_id object_id object_type )};

    return time;

}

sub thaw_data {
    my $sess = shift;
    return $sess->{__data} if $sess->{__data};
    my $data = $sess->data;
    $data = '' unless $data;
    require MT::Serialize;
    my $out = MT::Serialize->unserialize($data);
    if ( ref $out eq 'REF' ) {
        $sess->{__data} = $$out;
    }
    else {
        $sess->{__data} = {};
    }
    $sess->{__dirty} = 0;
    $sess->{__data};
}

sub get {
    my $sess  = shift;
    my ($var) = @_;
    my $data  = $sess->thaw_data;
    $data->{$var};
}

sub set {
    my $sess = shift;
    my ( $var, $val ) = @_;
    if ( $sess->kind eq q{US} and $var eq q{US} ) {
        $sess->name($val);
    }
    my $data = $sess->thaw_data;
    $sess->{__dirty} = 1;
    $data->{$var} = $val;
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

