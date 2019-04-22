package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';

use MT;
use MT::App::Auth::SharedPreviewAuth;
use MT::Preview;
use MT::SharedPreviewPluginData;
use MT::Validators::PreviewValidator;
use MT::Validators::SharedPreviewAuthValidator;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;

sub id          {'shared_preview'}
sub script_name { MT->config->SharedPreviewScript }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods( shared_preview       => \&shared_preview );
    $app->add_methods( make_shared_preview  => \&make_shared_preview );
    $app->add_methods( shared_preview_login => \&login );
    $app->add_methods( shared_preview_auth  => \&auth_login );

    return $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview';
}

sub auth_login {
    my $app = shift;
    my %validate
        = MT::Validators::SharedPreviewAuthValidator->login_validate($app);
    return $app->error( $validate{message} ) if $validate{error};

    my $check_result
        = MT::App::Auth::SharedPreviewAuth->check_auth( \%validate );

    return $app->error( $app->translate('Passwords do not match.') )
        unless $check_result;

    #TODO: セッション開始

    $app->redirect(
        $app->uri(
            mode => 'shared_preview',
            args => { spid => $validate{spid} },
        )
    );
}

sub login {
    my $app = shift;
    my %validate
        = MT::Validators::SharedPreviewAuthValidator->spid_validate($app);
    return $app->error( $validate{message} ) if $validate{error};

    my $preview_data
        = MT::Preview->get_preview_data_by_id( $validate{value} );
    return $app->error( $app->translate('not found : sharedd preview page.') )
        unless $preview_data;

    return $app->component('SharedPreview')->load_tmpl(
        'shared_preview_login.tmpl',
        {   query_params => [
                {   name  => 'spid',
                    value => $validate{value},
                },
                {   name  => '__mode',
                    value => 'shared_preview_auth',
                },
            ]
        }
    );
}

sub make_shared_preview {
    my $app = shift;
    my @params;
    my $result = MT::Validators::PreviewValidator->make_validator($app);
    return $app->error($result) if defined $result;

    my $type    = $app->param('_type');
    my $id      = $app->param('id');
    my $blog_id = $app->blog->id;
    my $created_id;

    if ( $type eq 'content_data' ) {
        @params = SharedPreview::CMS::ContentData::trim_parameter($app);
    }
    else {
        @params = SharedPreview::CMS::Entry::trim_parameter($app);
    }

    my $preview_obj = MT::Preview->new;

    if (my $preview = MT::Preview->load(
            {   blog_id     => $blog_id,
                object_type => $type,
                object_id   => $id,
            }
        )
        )
    {
        $created_id = $preview->id;
    }
    else {
        set_save_values( $preview_obj, \@params );
        $created_id = $preview_obj->id;
        $preview_obj->save
            or $app->error(
            "Could not create share preview link : " . $preview_obj->errstr );
    }

    $app->redirect(
        $app->uri(
            mode => 'shared_preview',
            args => { spid => $created_id },
        )
    );
}

sub set_save_values {
    my $preview_obj = shift;
    my ($set_data)  = @_;
    my $data        = {};

    for my $column ( keys $set_data ) {
        my $column_name = $set_data->[$column]{object_name};
        if ( $column_name eq 'data' ) {
            $data->{ $set_data->[$column]{data_name} }
                = $set_data->[$column]{data_value};
        }
        elsif ($column_name) {
            $preview_obj->$column_name( $set_data->[$column]{data_value} );
        }
    }

    if ($data) {
        $preview_obj->data($data);
    }

    $preview_obj->id( $preview_obj->make_unique_id );
    $preview_obj->{__dirty} = 1;
}

sub shared_preview {
    my $app    = shift;
    my $result = MT::Validators::PreviewValidator->view_validator($app);
    return $app->error($result) if defined $result;
    my $preview_id = $app->param('spid');

    my $need_login
        = MT::App::Auth::SharedPreviewAuth->need_login($preview_id);
    if ($need_login) {

        #TODO: セッションがあるかチェック
        MT::App::Auth::SharedPreviewAuth->check_auth();

        $app->redirect(
            $app->uri(
                mode => 'shared_preview_login',
                args => { spid => $preview_id },
            )
        );
    }
    my $preview = MT::Preview->get_preview_data_by_id($preview_id);

    &set_app_parameters( $app, $preview );

    my $param;
    my $type = $app->param('_type');

    #TODO: 処理まとめる
    if ( $type eq 'entry' || $type eq 'page' ) {
        $param = SharedPreview::CMS::Entry->_build_preview($app);
    }
    else {
        $param = SharedPreview::CMS::ContentData->_build_preview($app);
    }

    return unless defined $param;
    $param->{back_edit} = $app->app_path . MT->config->AdminScript;

    return $app->component('SharedPreview')
        ->load_tmpl( 'shared_preview_strip.tmpl', $param );
}

sub set_app_parameters {
    my ( $app, $preview ) = @_;
    $app->param( 'id',      $preview->object_id );
    $app->param( '_type',   $preview->object_type );
    $app->param( 'blog_id', $preview->blog_id );

    if ( $preview->object_type eq 'content_data' ) {
        $app->param( 'content_type_id', $preview->data->{content_type_id} );
    }
}

1;
