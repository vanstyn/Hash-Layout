# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use Test::Exception;

use_ok('Hash::Layout');

ok(
  my $HL = Hash::Layout->new({
    levels => [
      { name => 'source', delimiter => ':' },
      { name => 'column', delimiter => '/' }, 
      { name => 'info' }, 
    ]
  }),
  "Instantiate new Hash::Layout instance"
);

my $target1 = {
  "*" => {
    "*" => {
      column_info => 1
    }
  },
  Film => {
    id => {
      relationship_info => 1
    },
    rental_rate => {
      column_info => {
        foo => {
          baz => 2,
          blah => 1
        }
      }
    }
  }
};

is_deeply(
  $HL->clone->load(
    'column_info',
    'Film:id/relationship_info',
    'Film:rental_rate/column_info.foo.blah',
    { 'Film:rental_rate/column_info.foo.baz' => 2 }
  )->Data,
  $target1,
  "load values - target1 (1)"
);


is_deeply(
  $HL->clone->load(
  {
    "*" => {
      "*/column_info" => 1
    },
    'Film:id/' => {
      relationship_info => 1
    },
    Film => {
      rental_rate => {
        column_info => {
          foo => {
            baz => 2,
            blah => 1
          }
        }
      }
    }
  }
  )->Data,
  $target1,
  "load values - target1 (2)"
);

is_deeply(
  $HL->clone->load(
  {
    "*" => {
      "*/column_info" => 1
    },
    'Film:id' => { #<-- trailing '/' not needed
      relationship_info => 1
    },
    Film => {
      rental_rate => {
        column_info => {
          foo => {
            baz => 2,
            blah => 1
          }
        }
      }
    }
  }
  )->Data,
  $target1,
  "load values - target1 (3)"
);


done_testing;
