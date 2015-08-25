package Dash::Docset::Generator;

use strict;
use warnings;

use Moose;

use MooseX::Types::Path::Tiny qw/ Path /;
use MooseX::MungeHas 'is_rw';
use Path::Tiny;

use Web::Query::LibXML qw/ wq /;

use List::Util qw/ pairs /;

use experimental 'postderef';

has name => (
    required => 1,
);

has identifier => (
    lazy => 1,
    default => sub {
        my $self = shift;
        
        my $s = lc $self->name;
        $s =~ s/[^a-z0-9]/_/g;
        $s;
    }
);

has docs => (
    traits => [ qw/ Hash / ],
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
    handles => {
        add_doc => 'set'
    },
);

has js => (
    traits => [ qw/ Array / ],
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { [] },
    handles => {
        add_js => 'push'
    },
);

has css => (
    traits => [ qw/ Array / ],
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { [] },
    handles => {
        add_css => 'push'
    },
);

after add_doc => sub {
    my( $self, $filename, $doc ) = @_; 

    $doc->find(\'//*[@docset-type]')->each( sub{
        my $type = $_->attr( 'docset-type' );
        my $name = $_->attr( 'docset-name' ) || $_->text;

        my $anchor = $_->tagname eq 'a' ? $_ : $_->prepend('<a />');
        my $tag = $anchor->attr('name') || $anchor->attr( 'name', 
            join( '-', $type, $name ) =~ s/\s/_/gr
        );

        my $url =  join '#', $filename, $tag;

        $self->db->resultset('SearchIndex')->create({
            type => $type,
            name => $name,
            path => $url,
        });
    });
};


has output_dir => (
    is => 'ro',
    lazy => 1,
    isa => Path,
    coerce => 1,
    default => sub {
        path('.')
    },
    trigger => sub { $_[0]->output_dir->mkpath },
);

use Dash::Docset::Schema;

has db => (
    lazy => 1,
    default => sub {
        my $self = shift;
        
        my $db_dir = $self->output_dir->child($self->identifier . '.docset', 'Contents', 'Resources' );
        $db_dir->mkpath;
        my $db = Dash::Docset::Schema->connect( 
            'dbi:SQLite:database='.$db_dir->child('docSet.dsidx')
        );
        $db->deploy;
        $db;
    },
);


has doc_dir => (
    is => 'ro',
    lazy => 1,
    isa => Path,
    coerce => 1,
    default => sub {
        my $self = shift;
        my $x = $self->output_dir->child( $self->identifier . '.docset', 'Contents', 'Resources', 'Documents' );
        $x->mkpath;
        $x;
    }
);

sub generate {
    my $self = shift;
    
    $self->doc_dir;

    my $asset_dir = $self->doc_dir->child('assets');
    $asset_dir->mkpath;

    for my $css ( @{ $self->css } ) {
        path($css)->copy($asset_dir);        
        for my $doc ( values $self->docs->%*  ) {
            my $link = wq('<link/>');
            $link->attr( href => "assets/$css" );
            $link->attr( rel => 'stylesheet' );
            $doc->find('head')->append($link);
        }
    }

    for my $js ( @{ $self->js } ) {
        path($js)->copy($asset_dir);        
        for my $doc ( values $self->docs->%*  ) {
            my $link = wq('<script/>');
            $link->attr( src => "assets/$js" );
            $doc->find('head')->append($link);
        }
    }

    $self->doc_dir->child( $_->[0] )->spew( $_->[1]->as_html ) for pairs $self->docs->%*;

    $self->db;

    $self->write_info;
}

has platform_family => (
    required => 1,
);

has homepage => (
    required => 1,
);

sub write_info {
    my $self = shift;
    
    $self->output_dir->child( $self->identifier . '.docset', 'Contents', 'Info.plist' )->spew(<<"END");
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>@{[ $self->identifier ]}</string>
	<key>CFBundleName</key>
	<string>@{[ $self->name ]}</string>
	<key>DocSetPlatformFamily</key>
	<string>@{[ $self->platform_family]}</string>
	<key>isDashDocset</key> <true/>
    <key>DashDocSetFallbackURL</key>
    <string>@{[$self->homepage ]}</string>
</dict>
</plist>
END
}

1;


