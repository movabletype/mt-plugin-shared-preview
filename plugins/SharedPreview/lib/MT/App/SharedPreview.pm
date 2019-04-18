package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';
use Data::Dumper;

use MT;
use MT::Serialize;
use MT::Validators::PreviewValidator;
use MT::Preview;
use MT::PreviewSetting;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;

sub id          { 'shared_preview' }
sub script_name { MT->config->SharedPreviewScript }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods( shared_preview       => \&shared_preview );
    $app->add_methods( make_shared_preview  => \&make_shared_preview );
    $app->add_methods( shared_preview_login => \&login );

    return $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview';
}

sub shared_preview_setting {
    my ( $plugin, $param, $scope ) = @_;
    my @blog_parameter = split(/:/, $scope);
    my $parameter;

    if ($blog_parameter[1]) {
        $parameter = MT::PreviewSetting->load({blog_id => $blog_parameter[1]});
    }

    $plugin->load_tmpl( 'shared_preview_setting.tmpl', $parameter);
}

sub login {

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

    if (
        my $preview = MT::Preview->load(
            {
                blog_id     => $blog_id,
                object_type => $type,
                object_id   => $id,
            }
        )
      )
    {
        $created_id = $preview->id;
    }
    else {
        &set_save_values( $preview_obj, \@params );
        $created_id = $preview_obj->id;
        $preview_obj->save
          or $app->error(
            "Could not create share preview link : " . $preview_obj->errstr );
    }

    $app->redirect(
        $app->uri(
            mode => 'shared_preview',
            args => {
                spid => $created_id
            },
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
            $data->{ $set_data->[$column]{data_name} } =
              $set_data->[$column]{data_value};
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

    my $preview = MT::Preview->load( { id => $preview_id } );

    if (
        MT::PreviewSetting->load(
            { blog_id => $preview->blog_id, use_password => 0 }
        )
      )
    {
        # $app->redirect();
    }

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
