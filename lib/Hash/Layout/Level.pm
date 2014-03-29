package Hash::Layout::Level;
use strict;
use warnings;

use Moo;
use Types::Standard qw(:all);

has 'index',     is => 'ro', isa => Int, required => 1;
has 'delimiter', is => 'ro', isa => Maybe[Str], default => sub {undef};

has 'name',      is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  return 'level-' . $self->index;
};

has 'edge_keys', is => 'ro', isa => Maybe[
  Map[Str,Bool]
], coerce => \&_coerce_list_hash, default => sub {undef};

has 'deep_keys', is => 'ro', isa => Maybe[
  Map[Str,Bool]
], coerce => \&_coerce_list_hash, default => sub {undef};

has 'limit_keys', is => 'ro', isa => Bool, default => sub { 0 };



# Peel off the prefix key from a concatenated key string, according
# to this Level's delimiter:
sub _peel_str_key {
  my ($self,$key) = @_;
  my $del = $self->delimiter or return undef;
  return undef unless ($key =~ /\Q${del}\E/);
  my ($peeled,$leftover) = split(/\Q${del}\E/,$key,2);
  return undef unless ($peeled && $peeled ne '');
  return ($leftover && $leftover ne '' && wantarray) ? 
    ($peeled,$leftover) : $peeled;
}

sub _coerce_list_hash {
  $_[0] && ! ref($_[0]) ? { $_[0] => 1 } :
  ref($_[0]) eq 'ARRAY' ? { map {$_=>1} @{$_[0]} } : $_[0];
}

1;
