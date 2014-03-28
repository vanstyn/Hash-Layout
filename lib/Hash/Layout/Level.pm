package Hash::Layout::Level;
use strict;
use warnings;

use Moo;
use Types::Standard qw(:all);

has 'name',      is => 'ro', isa => Str, required => 1;
has 'index',     is => 'ro', isa => Int, required => 1;
has 'delimiter', is => 'ro', isa => Maybe[Str], default => sub { undef };

sub _peel_key {
  my ($self,$key) = @_;
  my $del = $self->delimiter or return $key;
  return ($key =~ /${del}/) ? split(/${del}/,$key,2) : ('*',$key);
}


1;

