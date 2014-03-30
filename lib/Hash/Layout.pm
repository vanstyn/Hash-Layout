package Hash::Layout;
use strict;
use warnings;

# ABSTRACT: Deep hashes with predefined layouts

our $VERSION = 0.01;

use Moo;
use Types::Standard qw(:all);
use Scalar::Util qw(blessed looks_like_number);
use Hash::Merge::Simple 'merge';
use Clone;

use Hash::Layout::Level;

has 'levels', is => 'ro', isa => ArrayRef[
  InstanceOf['Hash::Layout::Level']
], required => 1, coerce => \&_coerce_levels_param;

sub num_levels { scalar(@{(shift)->levels}) }

has 'default_key',       is => 'ro', isa => Str, default => sub { '*' };
has 'default_value',     is => 'ro', default => sub { 1 };
has 'allow_deep_values', is => 'ro', isa => Bool, default => sub { 1 };
has 'deep_delimiter',    is => 'ro', isa => Str, default => sub { '.' };

has '_Hash', is => 'ro', isa => HashRef, default => sub {{}}, init_arg => undef;
sub Data { (shift)->_Hash }

# Clears the Hash of any existing data
sub reset { %{(shift)->_Hash} = () }

sub clone { Clone::clone(shift) }


around BUILDARGS => sub {
  my ($orig, $self, @args) = @_;
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  
  # Accept 'levels' as shorthand numeric value:
  if($opt{levels} && looks_like_number $opt{levels}) {
    my $num = $opt{levels} - 1;
    $opt{delimiter} ||= '/';
    my @levels = ({ delimiter => $opt{delimiter} }) x $num;
    $opt{levels} = [ @levels, {} ];
    delete $opt{delimiter};
  }

  return $self->$orig(%opt);
};


sub BUILD {
  my $self = shift;
  $self->_post_validate;
}

sub _post_validate {
  my $self = shift;

  if($self->allow_deep_values) {
    for my $Lvl (@{$self->levels}) {
      die join("",
        "Level delimiters must be different from the deep_delimiter ('",
          $self->deep_delimiter,"').\n",
        "Please specify a different level delimiter or change 'deep_delimiter'"
      ) if ($Lvl->delimiter && $Lvl->delimiter eq $self->deep_delimiter);
    }
  }

}




sub coercer {
  my $self = shift;
  return sub { $self->coerce(@_) };
}

sub coerce {
  my $self = shift;

}


sub load {
  my $self = shift;
  return $self->_load(0,$self->_Hash,@_);
}

sub _load {
  my ($self, $index, $noderef, @args) = @_;
  
  my $Lvl = $self->levels->[$index] or die "Bad level index '$index'";
  my $last_level = ! $self->levels->[$index+1];
  
  for my $arg (@args) {
    
    my $force_composit = 0;
    unless (ref $arg) {
      # hanging string/scalar, convert using default value
      $arg = { $arg => $self->default_value };
      $force_composit = 1;
    }
    
    die "Cannot load non-hash reference!" unless (ref($arg) eq 'HASH');
    
    for my $key (keys %$arg) {
      die "Only scalar/string keys are allowed" 
        unless (defined $key && ! ref($key));
      
      my $val = $arg->{$key};
      
      if( $force_composit || $self->_is_composit_key($key,$index) ) {
        my @path = $self->resolve_key_path($key,$index);
        my $lkey = pop @path;
        my $hval = {};
        $self->_init_hash_path($hval,@path)->{$lkey} = $val;
        $self->_load($index,$noderef,$hval);
      }
      else {
        if(ref $val && ref($val) eq 'HASH') {
          $self->_init_hash_path($noderef,$key);
          if($last_level) {
            $noderef->{$key} = merge($noderef->{$key}, $val);
          }
          else {
            # Set via recursive:
            $self->_load($index+1,$noderef->{$key},$val);
          }
        }
        else {
          $noderef->{$key} = $val;
        }
      }
    }
  }
  
  return $self;
}


sub _init_hash_path {
  my ($self,$hash,@path) = @_;
  die "Not a hash" unless (ref $hash && ref($hash) eq 'HASH');
  die "No path supplied" unless (scalar(@path) > 0);
  
  my $ev_path = $self->_as_eval_path( @path );
  
  my $hval;
  eval join('','$hash->',$ev_path,' //= {}');
  eval join('','$hval = $hash->',$ev_path);
  eval join('','$hash->',$ev_path,' = {}') unless (
    ref $hval && ref($hval) eq 'HASH'
  );
  
  return $hval;
}


sub set {
  my ($self,$key,$value) = @_;
  die "bad number of arguments passed to set" unless (scalar(@_) == 3);
  die '$key value is required' unless ($key && $key ne '');
  
  my $eval_path = $self->_eval_key_path($key) 
    or die "Error resolving key string '$key'";
  
  eval join('','$self->_Hash->',$eval_path,' = $value');
}


sub _as_eval_path {
  my ($self,@path) = @_;
  return (scalar(@path) > 0) ? join('',
    map { '{"'.$_.'"}' } @path
  ) : undef;
}

sub _eval_key_path {
  my ($self, $key, $index) = @_;
  return $self->_as_eval_path(
    $self->resolve_key_path($key,$index)
  );
}

# recursively scans the supplied key for any special delimiters defined
# by any of the levels, or the deep delimiter, if deep values are enabled
sub _is_composit_key {
  my ($self, $key, $index) = @_;
  $index ||= 0;
  
  my $Lvl = $self->levels->[$index];

  if ($Lvl) {
    return $Lvl->_peel_str_key($key) || $self->_is_composit_key($key,$index+1);
  }
  else {
    if($self->allow_deep_values) {
      my $del = $self->deep_delimiter;
      return $key =~ /\Q${del}\E/;
    }
    else {
      return 0;
    }
  }
}

sub resolve_key_path {
  my ($self, $key, $index) = @_;
  $index ||= 0;
  
  my $Lvl = $self->levels->[$index];
  my $last_level = ! $self->levels->[$index+1];
  
  if ($Lvl) {
    my ($peeled,$leftover) = $Lvl->_peel_str_key($key);
    if($peeled) {
      # If a key was peeled, move on to the next level with leftovers:
      return ($peeled, $self->resolve_key_path($leftover,$index+1)) if ($leftover); 
      
      # If there were no leftovers, recurse again only for the last level,
      # otherwise, return now (this only makes a difference for deep values)
      return $last_level ? $self->resolve_key_path($peeled,$index+1) : $peeled;
    }
    else {
      # If a key was not peeled, add the default key at the top of the path
      # only if we're not already at the last level: 
      my @path = $self->resolve_key_path($key,$index+1);
      return $last_level ? @path : ($self->default_key,@path);
    }
  }
  else {
    if($self->allow_deep_values) {
      my $del = $self->deep_delimiter;
      return split(/\Q${del}\E/,$key);
    }
    else {
      return $key;
    }
  }
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
