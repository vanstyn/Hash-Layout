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


sub lookups1 {
  my $HL1 = shift;

  is(
    $HL1->lookup('Film:rental_rate/foobar'),
    'Film rental_rate foobar',
    "lookup (1)"
  );

  is(
    $HL1->lookup('Album:id/foobar'),
    'default foobar',
    "lookup (2)"
  );

  is(
    $HL1->lookup('Film:id/foobar'),
    'Film foobar',
    "lookup (3)"
  );

  is(
    $HL1->lookup('Album:rental_rate/foobar'),
    'rental_rate foobar',
    "lookup (4)"
  );
}

ok(
  my $HL1 = $HL->coerce(
    { '*/foobar'                => 'default foobar' },
    { 'rental_rate/foobar'      => 'rental_rate foobar' },
    { 'Film:foobar'             => 'Film foobar' },
    { 'Film:rental_rate/foobar' => 'Film rental_rate foobar' },
  ),
  "New via coerce()"
);

&lookups1($HL1);

ok(
  $HL1->lookup_mode('fallback'),
  "Change lookup_mode from default 'merge' to 'fallback'"
);

# 'fallback' is the same as 'merge' for scalar values:
&lookups1($HL1);


ok(
  $HL1->lookup_mode('get'),
  "Change lookup_mode to 'get'"
);

is(
  $HL1->lookup('Album:rental_rate/foobar'),
  undef,
  "lookup (5)"
);

is(
  $HL1->lookup('rental_rate/foobar'),
  'rental_rate foobar',
  "lookup (6)"
);

done_testing;

