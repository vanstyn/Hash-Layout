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

is_deeply(
  [ $HL->resolve_key_path('foo/') ],
  [ qw(* foo) ],
  'resolve_key_path (5)'
);

is_deeply(
  [ $HL->resolve_key_path('Film:column_info.foo.bar.blah') ],
  [ qw(Film * column_info foo bar blah) ],
  'resolve_key_path (6)'
);

ok(
  my $HL2 = Hash::Layout->new({
    allow_deep_values => 0,
    levels => [
      { name => 'source', delimiter => ':' },
      { name => 'column', delimiter => '/' }, 
      { name => 'info' }, 
    ]
  }),
  "Instantiate new Hash::Layout with 'allow_deep_values' off"
);

is_deeply(
  [ $HL2->resolve_key_path('Film:column_info.foo.bar.blah') ],
  [ qw(Film * column_info.foo.bar.blah) ],
  'resolve_key_path (6a)'
);


ok(
  my $HL3 = Hash::Layout->new({
    levels => [
      { delimiter => '/' },
      { delimiter => '/' }, 
      { delimiter => '/' }, 
      {}, 
    ]
  }),
  "Instantiate new Hash::Layout with levels using the same delimiter"
);


# These aren't all that useful as APIs since mapping for partial paths
# is at best ambiguous when all the levels use the same delimiter. But
# we're including these tests to make sure that the mapping for these
# at least remains consistent:
is_deeply(
  [ $HL3->resolve_key_path('foo/bar') ],
  [ qw(foo * * bar) ],
  'resolve_key_path (7)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo/*/*/bar') ],
  [ qw(foo * * bar) ],
  'resolve_key_path (8)'
);

is_deeply(
  [ $HL3->resolve_key_path('*/*/foo/bar') ],
  [ qw(* * foo bar) ],
  'resolve_key_path (9)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo/bar/') ],
  [ qw(foo bar) ],
  'resolve_key_path (10)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo') ],
  [ qw(* * * foo) ],
  'resolve_key_path (11)'
);

# TODO: the way this is resolved should probably be changed:
is_deeply(
  [ $HL3->resolve_key_path('/foo') ],
  [ qw(* * * /foo) ],
  'resolve_key_path (12)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo',1) ],
  [ qw(* * foo) ],
  'resolve_key_path (13) - relative to the second level (index 1)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo',3) ],
  [ qw(foo) ],
  'resolve_key_path (14) - relative to the fourth level (index 3)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo/bar',2) ],
  [ qw(foo bar) ],
  'resolve_key_path (15) - relative to the third level (index 2)'
);

is_deeply(
  [ $HL3->resolve_key_path('foo/bar/blah',50) ],
  [ qw(foo/bar/blah) ],
  'resolve_key_path (16) - relative to a non-existant level index'
);

is_deeply(
  [ $HL3->resolve_key_path('foo/bar/blah.plus.deep.path.boo/baz',50) ],
  [ qw(foo/bar/blah plus deep path boo/baz) ],
  'resolve_key_path (17) - relative to a non-existant level index with deep value'
);

is_deeply(
  [ $HL3->resolve_key_path('foo.bar/baz.boo') ],
  [ qw(foo.bar * * baz boo) ],
  'resolve_key_path (18) - level keys with deep delimiter character'
);


done_testing;



# -- for debugging:
#
#use Data::Dumper::Concise;
#print STDERR "\n\n" . Dumper(
#  $HL3->resolve_key_path('foo.bar/baz.boo')
#) . "\n\n";
