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

  use Mango::BSON;
  use Mango::BSON::Number;

  my $number = Mango::BSON::Number->new(666, Mango::BSON::INT64);
  say $number;

=head1 DESCRIPTION

L<Mango::BSON::Number> is a container for numerical values with a strict
type.

=head1 METHODS

L<Mango::BSON::Number> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 new

  my $number = Mango::BSON::Number->new(3.14, Mango::BSON::DOUBLE);

Construct a new L<Mango::BSON::Number> object. Croak if the value is
incompatible with the given type. The 3 supported types are C<DOUBLE>,
C<INT32> and C<INT64>.

=head2 TO_JSON

  my $num = $obj->TO_JSON;

Return the numerical value.

=head2 to_string

  my $str = $num->to_string;

Return the value as a string.

=head2 isa_number

  my $flags = Mango::BSON::Number::isa_number(25);

Determine if the given variable is a number by looking at the internal
flags of the perl scalar object.

Return C<undef> if the value is not a number, or a non-null value otherwise.
This value contains flags which can be used for finer analysis of the scalar.

=head2 guess_type

  my $mongo_type = Mango::BSON::Number::guess_type(25);

Chose which BSON type to use to encode the given numeric value. Possible
types are: C<Mango::BSON::DOUBLE>, C<Mango::BSON::INT32> or
C<Mango::BSON::INT64>.

Return C<undef> if the given value is not a number.

=head1 OPERATORS

L<Mango::BSON::Time> overloads the following operators.

=head2 bool

  my $bool = !!$num;

=head2 stringify

  my $str = "$num";

Alias for L</to_string>.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
