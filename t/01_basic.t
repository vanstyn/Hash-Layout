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
  [ $HL->resolve_key_path('Film:rental_rate/column_info') ],
  [ qw(Film rental_rate column_info) ],
  'resolve_key_path (1)'
);

is_deeply(
  [ $HL->resolve_key_path('Film:column_info') ],
  [ qw(Film * column_info) ],
  'resolve_key_path (2)'
);

is_deeply(
  [ $HL->resolve_key_path('column_info') ],
  [ qw(* * column_info) ],
  'resolve_key_path (3)'
);

is_deeply(
  [ $HL->resolve_key_path('Film:') ],
  [ qw(Film) ],
  'resolve_key_path (4)'
);

done_testing;



# -- for debugging:
#
#use Data::Dumper::Concise;
#print STDERR "\n\n" . Dumper(
#  $HL->resolve_key_path('Film:rental_rate/column_info')
#) . "\n\n";
