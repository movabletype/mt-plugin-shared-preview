package MT::App::SharedPreview;
use strict;
use warnings;

use base 'MT::App';

use MT;
use MT::Serialize;
use MT::Validators::PreviewValidator;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;


sub id {'shared_preview'}
sub script_name {MT->config->SharedPreviewScript}

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(shared_preview => \&shared_preview);
    $app->add_methods(dialog_shared_preview => \&show_dialog);
    return $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview';
}

sub show_dialog {
    my $app = shift;
    my $params;
    my $result = MT::Validators::PreviewValidator->validator($app);
    if ($result) {
        $params->{missing_data} = 1;
        $params->{missing_message} = $result;
    }
    else {
        my $type = $app->param('_type');
        my $id = $app->param('id');
        my @inputs = (
            {
                name  => 'id',
                value => $id,
            },
            {
                name  => '_type',
                value => $type,
            },
            {
                name  => 'blog_id',
                value => $app->blog->id,
            }
        );

        if ($type eq 'content_data') {
            my $content_type_id = $app->param('content_type_id');
            push @inputs,
                {
                    name  => 'content_type_id',
                    value => $content_type_id,
                }
        }

        $params->{inputs} = \@inputs;
    }

    $params->{dialog_title} = $app->translate("Show Shared Preview");

    return $app->component('SharedPreview')
        ->load_tmpl('shared_preview_dialog.tmpl', $params);
}

sub shared_preview {
    my $app = shift;
    my $result = MT::Validators::PreviewValidator->validator($app);
    return $app->error($result) if defined $result;
    warn MT->config->AdminScript;
    my $param;
    my $type = $app->param('_type');

    #TODO: 処理まとめる
    if ($type eq 'entry' || $type eq 'page') {
        $param = SharedPreview::CMS::Entry->_build_preview($app);
    }
    else {
        $param = SharedPreview::CMS::ContentData->_build_preview($app);
    }

    return unless defined $param;
    $param->{back_edit} = $app->app_path . MT->config->AdminScript;

    return $app->component('SharedPreview')
        ->load_tmpl('shared_preview_strip.tmpl', $param);
}

1;
