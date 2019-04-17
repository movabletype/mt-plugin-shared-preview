# Movable Type (r) (C) 2001-2019 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::Preview;
use strict;
use warnings;

use MT::Object;
@MT::Preview::ISA = qw(MT::Object);

use MT::Util qw(dirify);

__PACKAGE__->install_properties(
    {
        column_defs =>
            {
                'id'          => 'string(40) not null',
                'object_id'   => 'integer not null',
                'object_type' => 'string(50) not null',
                'blog_id'     => 'integer(11) not null',
                'data'        => {
                    type       => 'blob',
                    revisioned => 1,
                },
            },
        indexes     => {
            blog_tag => { columns => [ 'blog_id', 'object_type', 'object_id' ], },
        },
        primary_key => 'id',
        datasource  => 'preview',
    }
);

sub class_label {
    return MT->translate("Preview");
}

sub save {
    my $self = shift;
    if (my $data = $self->{__data}) {
        require MT::Serialize;
        my $ser = MT::Serialize->serialize(\$data);
        $self->data($ser);
    }
    $self->{__dirty} = 0;
    $self->SUPER::save(@_);
}

sub make_unique_id {
    my $self = shift;
    my %param = @_;
    my ($blog_id, $object_id, $object_type)
        = @param{qw(blog_id object_id object_type)};

    return time;
}

sub thaw_data {
    my $self = shift;
    return $self->{__data} if $self->{__data};
    my $data = $self->data;
    $data = '' unless $data;
    require MT::Serialize;
    my $out = MT::Serialize->unserialize($data);
    if (ref $out eq 'REF') {
        $self->{__data} = $$out;
    }
    else {
        $self->{__data} = {};
    }
    $self->{__dirty} = 0;
    $self->{__data};
}

sub get {
    my $self = shift;
    my ($var) = @_;
    my $data = $self->thaw_data;
    $data->{$var};
}

sub purge {
    my $class = shift;
    my ($kind, $ttl) = @_;

    $class = ref($class) if ref($class);

    my $terms = { $kind ? (kind => $kind) : () };
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

    $class->remove($terms, $args)
        or return $class->error($class->errstr);
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
1;

