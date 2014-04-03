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

has 'default_value',     is => 'ro',              default => sub { 1 };
has 'default_key',       is => 'ro', isa => Str,  default => sub { '*' };
has 'allow_deep_values', is => 'ro', isa => Bool, default => sub { 1 };
has 'deep_delimiter',    is => 'ro', isa => Str,  default => sub { '.' };
has 'no_fill',           is => 'ro', isa => Bool, default => sub { 0 };
has 'no_pad',            is => 'ro', isa => Bool, default => sub { 0 };

has 'lookup_mode', is => 'rw', isa => Enum[qw(get fallback merge)], 
  default => sub { 'merge' };

has '_Hash', is => 'ro', isa => HashRef, default => sub {{}}, init_arg => undef;
has '_all_level_keys', is => 'ro', isa => HashRef, default => sub {{}}, init_arg => undef;

# List of bitmasks representing every key path which includes
# a default_key, with each bit representing the level and '1' toggled on
# where the key is the default
has '_def_key_bitmasks', is => 'ro', isa => HashRef, default => sub {{}}, init_arg => undef;

sub Data { (shift)->_Hash }

sub level_keys {
  my ($self, $index) = @_;
  die 'level_keys() expects level index argument' 
    unless (looks_like_number $index);
    
  die "No such level index '$index'" 
    unless ($self->levels->[$index]);

  return $self->_all_level_keys->{$index} || {};
}

# Clears the Hash of any existing data
sub reset {
  my $self = shift;
  %{$self->_Hash}             = ();
  %{$self->_all_level_keys}   = ();
  %{$self->_def_key_bitmasks} = ();
  return $self;
}

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
  my $self = (shift)->clone;
  return sub { $self->coerce(@_) };
}

sub coerce { 
  my ($self, @args) = @_;
  die 'coerce() is not a class method' unless (blessed $self);
  if(scalar(@args) == 1 && ref($args[0])) {
    return $args[0] if (blessed($args[0]) eq __PACKAGE__);
    @args = @{$args[0]} if (ref($args[0]) eq 'ARRAY');
  }
  return $self->clone->reset->load(@args);
}


sub lookup {
  my ($self, @path) = @_;
   # lookup() is the same as get() when lookup_mode is 'get':
  return $self->get(@path) if ($self->lookup_mode eq 'get');
  
  return undef unless (defined $path[0]);
  @path = scalar(@path) > 1 ? @path : $self->resolve_key_path($path[0]);

  return $self->lookup_path(@path);
}

sub lookup_path {
  my ($self, @path) = @_;
   # lookup_path() is the same as get_path() when lookup_mode is 'get':
  return $self->get_path(@path) if ($self->lookup_mode eq 'get');
  
  return undef unless (defined $path[0]);
  
  my $hash_val;

  # If the exact path is set and is NOT a hash (that may need merging),
  # return it outright:
  if($self->exists_abs_path(@path)) {
    my $val = $self->get_path(@path);
    return $val unless (
      ref $val && ref($val) eq 'HASH'
      && $self->lookup_mode eq 'merge'
    );
    # Set the first hash_val:
    $hash_val = $val if(ref $val && ref($val) eq 'HASH');
  }
  
  my @set = $self->_enumerate_default_paths(@path);
  
  my @values = ();
  for my $dpath (@set) {
    $self->exists_abs_path(@$dpath) or next;
    my $val = $self->get(@$dpath);
    return $val unless ($self->lookup_mode eq 'merge');
    if (ref $val && ref($val) eq 'HASH') {
      # Set/merge hashes:
      $hash_val = $hash_val ? merge($val,$hash_val) : $val;
    }
    else {
      # Return the first non-hash value unless a hash has already been
      # encountered, and if that is the case, we can't merge a non-hash,
      # return the hash we already had now
      return $hash_val ? $hash_val : $val;
    }
  }
  
  # If nothing was found, $hash_val will still be undef:
  return $hash_val;
}


sub get {
  my ($self, @path) = @_;
  return undef unless (defined $path[0]);
  
  @path = scalar(@path) > 1 
    ? @path : $self->_is_composit_key($path[0])
    ? $self->resolve_key_path($path[0]) : @path;

  return $self->get_path(@path);
}

sub get_path {
  my ($self, @path) = @_;
  return undef unless (defined $path[0]);

  my $value;
  my $ev_path = $self->_as_eval_path(@path);
  eval join('','$value = $self->Data->',$ev_path);
  
  return $value;
}

sub exists_abs_path {
  my ($self, @path) = @_;
  return 0 unless (defined $path[0]);

  my $ev_path = $self->_as_eval_path(@path);
  return eval join('','exists $self->Data->',$ev_path);
}

# Use bitwise math to enumerate all possible prefix, default key paths:
sub _enumerate_default_paths {
  my ($self, @path) = @_;

  my $def_val = $self->default_key;
  my $depth = scalar @path;

  my @set = ();
  my %seen_combo = ();

  ## enumerate every possible default path bitmask (slow with many levels):
  #my $bits = 2**$depth;
  #my @mask_sets = ();
  #push @mask_sets, $bits while(--$bits >= 0);
  
  # default path bitmasks only for paths we know are set (much faster):
  my @mask_sets = keys %{$self->_def_key_bitmasks};
  
  # Re-sort the mask sets as reversed *strings*, because we want
  # '011' to come before '110'
  @mask_sets = sort { 
    reverse(sprintf('%0'.$depth.'b',$a)) cmp 
    reverse(sprintf('%0'.$depth.'b',$b)) 
  } @mask_sets;
  
  for my $mask (@mask_sets) {
    my @combo = ();
    my $check_mask =  2**$depth >> 1;
    for my $k (@path) {
      # Use bitwise AND to decide whether or not to swap the
      # default value for the actual key:
      push @combo, $check_mask & $mask ? $def_val : $k;
      
      # Shift the check bit position by one for the next key:
      $check_mask = $check_mask >> 1;
    }
    push @set, \@combo unless ($seen_combo{join('/',@combo)}++);
  }

  return @set;
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
      my $is_hashval = ref $val && ref($val) eq 'HASH';
      
      if( $force_composit || $self->_is_composit_key($key,$index) ) {
        my $no_fill = $is_hashval;
        my @path = $self->resolve_key_path($key,$index,$no_fill);
        my $lkey = pop @path;
        my $hval = {};
        $self->_init_hash_path($hval,@path)->{$lkey} = $val;
        $self->_load($index,$noderef,$hval);
      }
      else {
      
        local $self->{_path_bitmask} = $self->{_path_bitmask};
        my $bm = 0; $self->{_path_bitmask} //= \$bm;
        my $bmref = $self->{_path_bitmask};
        if($key eq $self->default_key) {
          my $depth = 2**($self->num_levels);
          $$bmref = $$bmref | ($depth >> $index+1);
        }
      
        $self->_all_level_keys->{$index}{$key} = 1;
        if($is_hashval) {
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
        
        if($index == 0 && $$bmref) {
          $self->_def_key_bitmasks->{$$bmref} = 1;
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
  $self->load({ $key => $value });
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
    return 0 if ($Lvl->registered_keys && $Lvl->registered_keys->{$key});
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
  my ($self, $key, $index, $no_fill) = @_;
  $index ||= 0;
  $no_fill ||= $self->no_fill;
  
  my $Lvl = $self->levels->[$index];
  my $last_level = ! $self->levels->[$index+1];
  
  if ($Lvl) {
    my ($peeled,$leftover) = $Lvl->_peel_str_key($key);
    if($peeled) {
      local $self->{_composit_key_peeled} = 1;
      # If a key was peeled, move on to the next level with leftovers:
      return ($peeled, $self->resolve_key_path($leftover,$index+1,$no_fill)) if ($leftover); 
      
      # If there were no leftovers, recurse again only for the last level,
      # otherwise, return now (this only makes a difference for deep values)
      return $last_level ? $self->resolve_key_path($peeled,$index+1,$no_fill) : $peeled;
    }
    else {
      # If a key was not peeled, add the default key at the top of the path
      # only if we're not already at the last level and 'no_fill' is not set
      # (and we've already peeled at least one key)
      my @path = $self->resolve_key_path($key,$index+1,$no_fill);
      my $as_is = $last_level || ($no_fill && $self->{_composit_key_peeled});
      return $self->no_pad || $as_is ? @path : ($self->default_key,@path);
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
