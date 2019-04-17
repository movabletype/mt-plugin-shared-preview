package MT::App::SharedPreviewSetting;
use strict;
use warnings;

use base 'MT::App';

use MT;
use MT::Serialize;
use MT::Validators::PreviewValidator;
use MT::Preview;
use SharedPreview::CMS::Entry;
use SharedPreview::CMS::ContentData;


sub id {'shared_preview_setting'}
sub script_name {MT->config->AdminScript}

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(shared_preview_setting => \&edit);
    $app->add_methods(shared_preview_setting_save => \&save);

    return $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'shared_preview_setting';
}

sub edit {

}

sub save {

}

1;
