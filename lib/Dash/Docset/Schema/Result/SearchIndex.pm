package Dash::Docset::Schema::Result::SearchIndex;

use strict;
use warnings;

use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('searchIndex');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    name => { data_type => 'text' },
    type => { data_type => 'text' },
    path => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint(
    'unique_entries' => [ qw/ name path type /],
);

1;


