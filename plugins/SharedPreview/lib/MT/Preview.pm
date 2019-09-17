# Movable Type (r) (C) 2001-2019 Six Apart Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::Preview;
use strict;
use warnings;

use MT::Object;
use MT::Serialize;
use MT::Util qw( perl_sha1_digest_hex encode_js);

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

sub can_create_shared_preview {
    my $self = shift;
    my ( $app, $blog_id, $type, $id ) = @_;
    if ( $type eq 'content_data' ) {
        my $allowed;
        my $content_data = $app->model('content_data')->load($id);
        my $content_type_unique_id
            = $content_data->content_type
            ? $content_data->content_type->unique_id
            : '';
        my $iter = $app->model('permission')->load_iter(
            {   author_id => $app->user->id,
                blog_id   => $blog_id,
            }
        );

        while ( my $p = $iter->() ) {
            my $create_allowed;

            if ( $p->has("create_content_data:$content_type_unique_id") ) {
                $create_allowed = 1
                    if $content_data->author_id == $app->user->id;
            }

            $allowed = 1, last
                if $create_allowed
                || $p->has("edit_all_content_data:$content_type_unique_id");
        }

        return $allowed
            || $app->permissions->can_do("create_new_${type}_shared_preview");

    }
    else {
        my $entry = $app->model('entry')->load($id);
        my $can_post;
        $can_post
            = (    $app->permissions->can_create_post
                && $entry->author_id == $app->user->id )
            if $entry;

        return $can_post
            || $app->permissions->can_do("create_new_${type}_shared_preview");
    }

}

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

sub validate_preview_id {
    my ($preview_id) = @_;
    return $preview_id && $preview_id =~ /\A[0-9a-f]{40}\z/;
}

sub shared_preview_link {
    my ( $app, $type, $href ) = @_;

    my $tmpl = $app->component('SharedPreview')
        ->load_tmpl( 'shared_preview_widget.tmpl', { 'href' => $href } );

    return '' unless $tmpl;

    my $output = $tmpl->output or return '';

    $output = $app->translate_templatized($output);
    $output =~ s/\r|\r\n|\n//g;
    $output = encode_js($output);

    return <<"__JS__";
    jQuery('#entry-publishing-widget').before('$output');
__JS__
}

sub shared_preview_message {
    my ( $app, $href ) = @_;
    my $type   = $app->param('_type');
    my $method = 'append';
    my $add_content_data;
    my $action_type;

    return '' unless $type;

    if ( $app->param('saved_added') ) {
        $action_type = 'saved-added';
        if ( $type eq 'content_data' ) {
            $add_content_data = '1';
            $method           = 'after';
        }
    }
    elsif ( $app->param('saved_changes') ) {
        $action_type = 'saved-changes';
    }

    return '' unless $action_type;

    my $tmpl
        = $app->component('SharedPreview')
        ->load_tmpl( 'shared_preview_message.tmpl',
        { 'href' => $href, 'add_content_data' => $add_content_data } );

    return '' unless $tmpl;
    my $output = $tmpl->output or return '';

    $output = $app->translate_templatized($output);
    $output =~ s/\r|\r\n|\n//g;
    $output = encode_js($output);

    return <<"__JS__";
jQuery('#$action_type').$method('$output');
__JS__

}

1;

