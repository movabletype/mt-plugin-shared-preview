package SharedPreview::CMS::Entry;
use strict;
use warnings;

sub on_template_param_edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;

    return unless $app->param('id');

    my $href = $app->app_path . $app->config->SharedPreviewScript;
    $href .= $app->uri_params(
        mode => 'shared_preview',
        args => {
            blog_id => $app->blog->id,
            _type   => scalar $app->param('_type'),
            id      => scalar $app->param('id'),
        },
    );

    ( $param->{jq_js_include} ||= '' ) .= <<"__JS__";
jQuery('button[name=preview_entry]').after('<div class="text-right"><a href="$href" target="_blank">Shared Preview</a></div>');
__JS__
}

1;

