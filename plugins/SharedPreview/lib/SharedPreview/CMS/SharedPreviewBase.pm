package SharedPreview::CMS::SharedPreviewBase;
use strict;
use warnings;

sub new {
    my ( $class, $app ) = @_;
    return undef unless $app->param('id');

    my $property = {
        'type' => scalar $app->param('_type'),
        'href' => $app->app_path . $app->config->SharedPreviewScript,
    };

    bless $property, $class;
}

sub add_shared_preview_link {
    my ( $class, $href ) = @_;
    my $type = $class->{type};
    my $link = $class->{href} . $href;
    my $release_status = MT::Entry::RELEASE();

    return <<"__JS__";
jQuery('button[name=preview_$type]').after('<div id="shared_preview" class="text-right"><a href="$link">Shared Preview</a></div>');

    function switch_display_preview() {
        if (jQuery('input[name=old_status]').val() != $release_status) {
            jQuery("#shared_preview").show();
        } else {
            jQuery("#shared_preview").hide();
        }
    }

    switch_display_preview();
__JS__
}

1;
