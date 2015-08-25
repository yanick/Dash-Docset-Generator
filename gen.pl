#!/usr/bin/perl 

use 5.20.0;

use strict;
use warnings;

use Dash::Docset::Generator;
use Text::MultiMarkdown qw/ markdown /;
use Path::Tiny;
use Web::Query::LibXML;
use List::Util qw/ pairs /;

my $docset = Dash::Docset::Generator->new( 
    name => "Swagger 2.0",
    platform_family => 'swagger',
    output_dir => '.',
    homepage => 'https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md',
);

my $index = new_doc();
$index->find('body')->append( path('index.html')->slurp );

my %files = ( 'index.html' => $index );

# process all the schema objects
$index->find('h4')->each(sub{
    warn $_->text;
        
    return unless $_->text =~ / ^ (.*) \s+ Object \s* $ /x;
    my $file = $1.'.html' =~ s/ /_/gr;

    my $t = $_->text;
    $_->find('a')->attr( 'docset-type' => 'Object' );
    $_->find('a')->attr( 'docset-name' => $t );

    my $content = wq('<html><head/><body/></html>');

    $files{$file} = $content;

    $content->find('body')->append($_)->append($_->next_until('h4'));
    $_->next_until('h4')->remove;
    $_->remove;

    $content->find( 'a' )->each( sub {
        my $ref = $_->attr('name') or return;
        my $xpath = "//a[\@href='#$ref']";

        $_->find(\$xpath)->each(sub{
            $_->attr('href', $file . $_->attr('href') );
        }) for values %files;
    });


});

{
    # process the type section
    
    my $type = wq('<html><head/><body/></html>');
    my $x = $index->find('h3')->filter(sub{ $_->text =~ /Data Types/ });
    my $t = $x->text;
    my $a = $x->prepend( '<a/>' );

    $a->attr( 'docset-type' => 'Type' );
    $a->attr( 'docset-name' => $t );

    my $block = $x->add( $x->next_until('h3') );
    $type->find('body')->append($block);
    $block->remove;

    $files{'types.html'} = $type;

    $type->find( 'a' )->each( sub {
        my $ref = $_->attr('name') or return;
        my $xpath = "//a[\@href='#$ref']";

        $_->find(\$xpath)->each(sub{
            $_->attr('href', 'types.html' . $_->attr('href') );
        }) for values %files;
    });

}

$docset->add_doc( $_->[0], $_->[1] ) for pairs %files;
$docset->add_css( 'github-style.css' );
$docset->add_js( 'prism.js' );
$docset->add_css( 'prism.css' );

$docset->generate;


sub new_doc {
    wq( '<html><head/><body/></html>' );
}

