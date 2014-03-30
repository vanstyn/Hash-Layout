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


is_deeply(
  $HL->clone->load(
    'column_info',
    'Film:id/relationship_info',
    'Film:rental_rate/column_info.foo.blah',
    { 'Film:rental_rate/column_info.foo.baz' => 2 }
  )->Data,
  {
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
  },
  "load values (1)"
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
  {
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
  },
  "load values (2)"
);


done_testing;
