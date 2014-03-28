package Hash::Layout;
use strict;
use warnings;

# ABSTRACT: Deep hashes with predefined levels

our $VERSION = 0.01;

use Moo;
use Types::Standard qw(:all);
use Scalar::Util qw(blessed);

use Hash::Layout::Level;

has 'levels', is => 'ro', isa => ArrayRef[
  InstanceOf['Hash::Layout::Level']
], required => 1, coerce => \&_coerce_levels_param;

sub num_levels { scalar(@{(shift)->levels}) }

has 'default_value', is => 'ro', default => sub { 1 };

has 'Hash', is => 'ro', isa => HashRef, default => sub {{}}, init_arg => undef;

# Clears the Hash of any existing data
sub reset { %{(shift)->Hash} = () }


sub coercer {
  my $self = shift;
  return sub { $self->coerce(@_) };
}

sub coerce {
  my $self = shift;

}


sub set {
  my ($self,$key,$value) = @_;
  die "bad number of arguments passed to set" unless (scalar(@_) == 3);
  die '$key value is required' unless ($key && $key ne '');

}

sub _eval_key_path {
  my ($self, $key) = @_;
  my @path = $self->resolve_key_path($key);
  return undef unless (scalar(@path) > 0);
  return join('',map { '{"'.$_.'"}' } @path);
}

sub resolve_key_path {
  my ($self, $key) = @_;
  
  my @path = ();
  for my $Lvl (@{$self->levels}) {
    my ($k,$leftover) = $Lvl->_peel_key($key);
    $k = '*' if ($leftover && (!$k || $k eq ''));
    last unless ($k && $k ne '');
    push @path, $k;
    last unless ($leftover && $leftover ne '');
    $key = $leftover;
  }
  
  return @path;
}



sub _coerce_levels_param {
  my $val = shift;
  return $val unless (ref($val) && ref($val) eq 'ARRAY');
  
  my %seen = ();
  my $i = 0;
  my @new = ();
  for my $itm (@$val) {
    return $val if (blessed $itm);
  
    die "'levels' must be an arrayref of hashrefs" unless (
      ref($itm) && ref($itm) eq 'HASH'
    );
    
    die "duplicate level name '$itm->{name}'" if (
      $itm->{name} && $seen{$itm->{name}}++
    );
    
    die "the last level is not allowed to have a delimiter" if(
      scalar(@$val) == ++$i
      && $itm->{delimiter}
    );
    
    push @new, Hash::Layout::Level->new({
      %$itm,
      index => $i-1
    });
  }
  
  die "no levels specified" unless (scalar(@new) > 0);
  
  return \@new;
}

1;


__END__

=head1 NAME

Hash::Layout - Deep hashes with predefined layouts

=head1 SYNOPSIS

 use Hash::Layout;



=head1 DESCRIPTION



=cut
