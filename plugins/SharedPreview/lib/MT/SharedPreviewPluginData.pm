package MT::SharedPreviewPluginData;
use strict;
use warnings;

use base qw( MT::Object );
use MT::Serialize;
use MT::PluginData;

sub search_plugin_data_by_preview_id {
    my $self       = shift;
    my $preview_id = @_;

    my @plugin_data = MT::PluginData->search( { plugin => 'SharedPreview' } );
    my $result;

    if (@plugin_data) {
        foreach my $data (@plugin_data) {
            $result = $data if $data->data->{spid} eq $preview_id;
        }
    }

    return $result;
}

1;
