package SharedPreview::CMS::SharedPreviewBase;
use strict;
use warnings;
use MT::Preview;
sub new {
    my ($class, $app) = @_;
    return undef unless $app->param('id') || $class->can_shared_preview;

    my $property = {
        'type'     => scalar $app->param('_type'),
        'href' => $app->app_path . $app->config->SharedPreviewScript,
    };

    bless $property, $class;
};

sub can_shared_preview {
    1;
}

sub add_shared_preview_link {
    my($class, $href) = @_;
    my $type = $class->{type};
    my $link = $class->{href} . $href;
    my $release_status = MT::Entry::RELEASE();

    return <<"__JS__";
jQuery('button[name=preview_$type]').after('<div id="shared_preview" style="display:none;" class="text-right"><a href="$link" class="mt-open-dialog mt-modal-open">Shared Preview</a></div>');
    jQuery('select[name=status]').on('change', function(){
        switch_display_preview();
    });
    function switch_display_preview() {
        if (jQuery('select[name=status]').val() != $release_status) {
            jQuery("#shared_preview").show();
        } else {
            jQuery("#shared_preview").hide();
        }
    }
    switch_display_preview();
__JS__
}

1;