use strict;
use warnings;
use FindBin;
use Cwd;

use lib Cwd::realpath("./t/lib");
use Test::More;
use MT::Test::Env;

our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new(
        PluginPath => [ Cwd::realpath("$FindBin::Bin/../../../plugins") ], );

    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT;
use MT::Test;
use MT::Test::Fixture;
use MT::Test::Permission;
use MT::Association;

MT::Test->init_app;

$test_env->prepare_fixture('db');

my $blog1_name = 'SharedPreviewBlog1-' . time();
my $blog2_name = 'SharedPreviewBlog2-' . time();
my $blog3_name = 'SharedPreviewBlog3-' . time();
my $blog4_name = 'SharedPreviewBlog4-' . time();

my $super = 'super';
my $objs  = MT::Test::Fixture->prepare(
    {   author => [ { 'name' => $super }, ],
        blog   => [
            { name => $blog1_name, },
            { name => $blog2_name, },
            { name => $blog3_name, },
            { name => $blog4_name, }
        ],
    }
);

my $blog1 = MT->model('blog')->load( { name => $blog1_name } ) or die;
my $blog2 = MT->model('blog')->load( { name => $blog2_name } ) or die;
my $blog3 = MT->model('blog')->load( { name => $blog3_name } ) or die;
my $blog4 = MT->model('blog')->load( { name => $blog4_name } ) or die;

my $super_author = MT->model('author')->load( { name => $super } ) or die;

my $plugin_data1 = MT::Test::Permission->make_plugindata(
    plugin => 'SharedPreview',
    key    => 'configuration:blog:' . $blog1->id,
    data   => { 'sp_password[]' => [ 'test', 'test2' ] }
);
my $plugin_data2 = MT::Test::Permission->make_plugindata(
    plugin => 'SharedPreview',
    key    => 'configuration:blog:' . $blog2->id,
);

subtest 'shared preview setting' => sub {
    subtest 'one password' => sub {
        my $output = request_setting( $blog2->id );
        ok( $output, 'Output' ) or return;
        check_setting($output);
    };

    subtest 'two password' => sub {
        my $output = request_setting( $blog1->id );
        ok( $output, 'Output' ) or return;
        check_setting($output);
    };

    subtest 'save shared preview setting' => sub {
        subtest 'one password' => sub {
            my @password = ('saved1');
            my $output
                = post_setting( $blog1->id, \@password, 1, $super_author );
            ok( $output, 'Output' ) or return;
            check_saved_setting( \@password, $blog1->id );
        };

        subtest 'two passwords' => sub {
            my @password = ( 'saved1', 'saved2' );
            my $output
                = post_setting( $blog3->id, \@password, 1, $super_author );
            ok( $output, 'Output' ) or return;
            check_saved_setting( \@password, $blog3->id );
        };
    };

    subtest 'timeout' => sub {
        my @password = ('saved1');
        my $blog_id  = $blog4->id;
        my $output   = post_setting( $blog4->id, \@password, 0 );
        ok( $output, 'Output' ) or return;
        like(
            $output,
            qr/(<input.*type="hidden".*name="plugin_sig".*value="SharedPreview")/,
            'plugin_sig'
        );
        like( $output,
            qr/(<input.*type="hidden".*name="blog_id".*value="$blog_id")/,
            'blog_id' );
        like(
            $output,
            qr/(<input.*type="hidden".*name="sp_password\[\]".*value="saved1")/,
            'shared preview password'
        );
        like(
            $output,
            qr/(<input.*type="hidden".*name="__mode".*value="save_plugin_config")/,
            'plugin_sig'
        );

        unlike(
            $output,
            qr/(<input type="text" name="username" id="username".*value="saved1".*\/>)/,
            'username is empty'
        );
        unlike(
            $output,
            qr/(<input type="password" name="password" id="password".*value="saved1".*\/>)/,
            'password is empty'
        );
    }

};

sub check_setting {
    my ($output) = @_;
    like( $output, qr/Status: 200/,   'Status is 200' );
    like( $output, qr/SharedPreview/, 'Shared Preview Plugin' );
    like(
        $output,
        qr/(Enable to share preview of entry, page and content data\.)/,
        'Explanatory text'
    );
    like( $output, qr/(<input.*name="sp_password\[\]")/, 'text box' );
    like(
        $output,
        qr/(<a href="javascript:void\(0\);".*id="add_password".*>.*Add Password\.<\/a>)/,
        'add password'
    );
}

sub check_saved_setting {
    my ( $passwords, $blog_id ) = @_;
    my $plugin_data = MT::PluginData->load(
        {   plugin => 'SharedPreview',
            key    => 'configuration:blog:' . $blog_id,
        }
    );

    ok( $plugin_data, 'plugin data' ) or return;

    if ( ref( $plugin_data->data->{'sp_password[]'} ) eq 'ARRAY' ) {
        foreach my $value ( @{$passwords} ) {
            ok( grep { $_ eq $value }
                    @{ $plugin_data->data->{'sp_password[]'} },
                'password registered' . $value
            );
        }

    }
    else {
        ok( $passwords->[0] eq $plugin_data->data->{'sp_password[]'},
            'password registered' );
    }
}

sub request_setting {
    my ($blog_id) = @_;
    my $app = _run_app(
        'MT::App::CMS',
        {   __test_follow_redirects => 1,
            __test_user             => $super_author,
            __mode                  => 'cfg_plugins',
            blog_id                 => $blog_id,
        },
    );

    my $output = delete $app->{__test_output};
    return $output || '';
}

sub post_setting {
    my ( $blog_id, $password, $redirect, $author ) = @_;
    my %parameters = (
        __test_follow_redirects => $redirect,

        __request_method => 'POST',
        __mode           => 'save_plugin_config',
        blog_id          => $blog_id,
        plugin_sig       => 'SharedPreview'
    );

    $parameters{'sp_password[]'} = $password;
    $parameters{__test_user}     = $author if $author;

    my $app = _run_app( 'MT::App::CMS', \%parameters );

    my $output = delete $app->{__test_output};
    return $output || '';

}

done_testing;
