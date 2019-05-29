# Movable Type (r) (C) 2001-2019 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::Preview;
use strict;
use warnings;

use MT::Object;
use MT::Serialize;
use MT::Util qw( perl_sha1_digest_hex );

@MT::Preview::ISA = qw(MT::Object);

use MT::Util qw(dirify);

__PACKAGE__->install_properties(
    {   column_defs => {
            'id'              => 'string(40) not null',
            'object_id'       => 'integer not null',
            'object_type'     => 'string(50) not null',
            'blog_id'         => 'integer(11) not null',
            'content_type_id' => 'integer(11)',
        },
        indexes => {
            blog_tag =>
                { columns => [ 'blog_id', 'object_type', 'object_id' ], },
        },
        primary_key => 'id',
        datasource  => 'preview',
    }
);

sub USE_PASSWORD_VALID {1}

sub class_label {
    return MT->translate("Preview");
}

sub make_unique_id {
    my $self = shift;

    my $key
        = join( $self->blog_id, $self->object_id, $self->object_type, time );

    return MT::Util::perl_sha1_digest_hex($key);

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
    my $args  = {};
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

{
    my $ser = MT::Serialize->new('MT');

    sub data {
        my $obj = shift;
        if (@_) {
            my $data;
            if ( ref $_[0] ) {
                $data = $ser->serialize( \$_[0] );
            }
            else {
                $data = $_[0];
            }
            $obj->column( 'data', $data );
        }
        else {
            my $raw_data = $obj->column('data');
            return {} unless defined $raw_data;
            if ( $raw_data =~ /^SERG/ ) {
                my $data = $ser->unserialize($raw_data);
                $data ? $$data : {};
            }
            else {
                require Encode;
                require JSON;
                my $data;
                if ( Encode::is_utf8($raw_data) ) {
                    $data = eval { JSON::from_json($raw_data) } || {};
                }
                else {
                    $data = eval { JSON::decode_json($raw_data) } || {};
                }
                warn $@ if $@ && $MT::DebugMode;
                $data;
            }
        }
    }
}

sub add_shared_preview_link {
    my ( $class, $type, $href ) = @_;

    return <<"__JS__";
jQuery('button[name=preview_$type]').after('<div id="shared_preview" class="text-right"><a href="$href">Shared Preview</a></div>');
__JS__
}

1;

