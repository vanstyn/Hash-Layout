# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use Hash::Layout;

# Create new Hash::Layout object with 3 levels and unique delimiters:
my $HL = Hash::Layout->new({
 levels => [
   { delimiter => ':' },
   { delimiter => '/' }, 
   {}, # <-- last level never has a delimiter
 ]
});

# load using actual hash structure:
$HL->load({
  '*' => {
    '*' => {
      foo_rule => 'always deny',
      blah     => 'thing'
    },
    NewYork => {
      foo_rule => 'prompt'
    }
  }
});

# load using composite keys:
$HL->load({
  'Office:NewYork/foo_rule' => 'allow',
  'Store:*/foo_rule'        => 'other',
  'Store:London/blah'       => 'purple'
});

# lookup values
is($HL->lookup('foo_rule')                  => 'always deny'         );
is($HL->lookup('ABC:XYZ/foo_rule')          => 'always deny'         );
is($HL->lookup('Lima/foo_rule')             => 'always deny'         );
is($HL->lookup('NewYork/foo_rule')          => 'prompt'              );
is($HL->lookup('Office:NewYork/foo_rule')   => 'allow'               );
is($HL->lookup('Store:foo_rule')            => 'other'      );


my $hash = $HL->Data;

is_deeply(
  $hash,
  {
    "*" => {
      "*" => {
        blah => "thing",
        foo_rule => "always deny"
      },
      NewYork => {
        foo_rule => "prompt"
      }
    },
    Office => {
      NewYork => {
        foo_rule => "allow"
      }
    },
    Store => {
      "*" => {
        foo_rule => "other"
      },
      London => {
        blah => "purple"
      }
    }
  },
  "Data"
);


done_testing;



