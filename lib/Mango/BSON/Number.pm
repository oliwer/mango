package Mango::BSON::Number;
use Mojo::Base -base;
use overload bool => sub { !!shift->value }, '""' => sub { shift->to_string },
             fallback => 1;

use B;
use Carp 'croak';

# 32bit integer range
use constant { INT32_MIN => -(1 << 31) + 1, INT32_MAX => (1 << 31) - 1 };

has [qw(value type)];

sub new {
  my ($class, $value, $type) = @_;

  return undef unless defined $value;
  $type //= Mango::BSON::DOUBLE();

  my $guessed_type = guess_type($value) or
    croak "Not a numerical value: '$value'";

  # Make sure the requested type is coherent with the value
  if ($guessed_type ne $type) {

    # We detected a double but user wants an int
    croak "Cannot save value '$value' as an integer"
      if $guessed_type eq Mango::BSON::DOUBLE();

    # We detected an int64 but user wants an int32
    croak "Cannot save value '$value' as an INT32"
      if $guessed_type > $type;
  }

  return $class->SUPER::new(value => $value, type => $type);
}

sub TO_JSON { 0 + shift->value }

sub to_string { '' . shift->value }


sub isa_number {
  my $value = shift;

  my $flags = B::svref_2object(\$value)->FLAGS;

  if ($flags & (B::SVp_IOK | B::SVp_NOK)) {
    if (0 + $value eq $value && $value * 0 == 0) {
      return $flags;
    }
  }

  return undef;
}

sub guess_type {
  my $value = shift;

  if (my $flags = isa_number($value)) {
    # Double
    return Mango::BSON::DOUBLE() if $flags & B::SVp_NOK;

    # Int32
    return Mango::BSON::INT32() if $value <= INT32_MAX && $value >= INT32_MIN;

    # Int64
    return Mango::BSON::INT64();
  }

  return undef;
}

1;

=encoding utf8

=head1 NAME

Mango::BSON::Number - Numerical types

=head1 SYNOPSIS

  use Mango::BSON::Time;

  my $time = Mango::BSON::Time->new(time * 1000);
  say $time->to_epoch;

=head1 DESCRIPTION

L<Mango::BSON::Time> is a container for the BSON datetime type used by
L<Mango::BSON>.

=head1 METHODS

L<Mango::BSON::Time> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 new

  my $time = Mango::BSON::Time->new;
  my $time = Mango::BSON::Time->new(time * 1000);

Construct a new L<Mango::BSON::Time> object.

=head2 TO_JSON

  my $num = $time->TO_JSON;

Numeric representation of time.

=head2 to_datetime

  my $str = $time->to_datetime;

Convert time to L<RFC 3339|http://tools.ietf.org/html/rfc3339> date and time.

=head2 to_epoch

  my $epoch = $time->to_epoch;

Convert time to floating seconds since the epoch.

=head2 to_string

  my $str = $time->to_string;

Stringify time.

=head1 OPERATORS

L<Mango::BSON::Time> overloads the following operators.

=head2 bool

  my $bool = !!$time;

Always true.

=head2 stringify

  my $str = "$time";

Alias for L</to_string>.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
