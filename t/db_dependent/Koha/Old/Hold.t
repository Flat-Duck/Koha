#!/usr/bin/perl

# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 1;

use Koha::Database;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'anonymize() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    is( $patron->old_holds->count, 0, 'Patron has no old holds' );

    my $hold_1 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { borrowernumber => $patron->id }
        }
    );
    my $hold_2 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { borrowernumber => $patron->id }
        }
    );

    is( $patron->old_holds->count, 2, 'Patron has 2 completed holds' );

    t::lib::Mocks::mock_preference( 'AnonymousPatron', undef );

    $hold_1->anonymize;

    is( $patron->old_holds->count, 1, 'Patron has 1 linked completed holds' );

    # Reload
    $hold_1->discard_changes;
    $hold_2->discard_changes;
    is( $hold_1->borrowernumber, undef,
        'Anonymized hold not linked to patron' );
    is( $hold_2->borrowernumber, $patron->id,
        'Not anonymized hold still linked to patron' );

    my $anonymous_patron =
      $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_preference( 'AnonymousPatron', $anonymous_patron->id );

    # anonymize second hold
    $hold_2->anonymize;
    $hold_2->discard_changes;
    is( $hold_2->borrowernumber, $anonymous_patron->id,
        'Anonymized hold linked to anonymouspatron' );

    $schema->storage->txn_rollback;
};
