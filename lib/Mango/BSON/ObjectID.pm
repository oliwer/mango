package Mango::BSON::ObjectID;
use Mojo::Base -base;
use overload bool => sub {1}, '""' => sub { shift->hex }, fallback => 1;

use Carp 'croak';
use Mojo::Util qw(deprecated md5_bytes);
use Sys::Hostname 'hostname';

# 3 byte machine identifier
my $MACHINE = substr md5_bytes(hostname), 0, 3;

# Global counter
my $COUNTER = int(rand(0xffffff));

sub TO_JSON { shift->hex }

sub from_epoch {
  deprecated "from_epoch is DEPRECATED. Do not use the OID to store a date!"
    unless $ENV{TAP_VERSION};
  my ($self, $epoch) = @_;
  $self->{oid} = _generate($epoch);
  return $self;
}

sub get_time { unpack 'N', substr(shift->oid, 0, 4) }

sub hex { unpack 'H*', shift->oid }

sub new {
  my ($class, $oid) = @_;

  # Make sure people are using bson_oid
  if ( (caller)[0] !~ /^Mango::/ ) {
    warn "You should never use the Mango::BSON::ObjectID constructor ".
         "directly. Use bson_oid from Mango::BSON instead.";
  }

  return $class->SUPER::new unless defined $oid;
  croak qq{Invalid object id "$oid"} if $oid !~ /^[0-9a-fA-F]{24}\z/;
  return $class->SUPER::new(oid => pack('H*', $oid));
}

sub oid { shift->{oid} //= _generate() }

sub to_bytes {
  deprecated "to_bytes is DEPRECATED in favor of oid";
  return shift->oid;
}

sub to_epoch {
  deprecated "to_epoch is DEPRECATED in favor of get_time";
  return shift->get_time;
}

sub to_string {
  deprecated "to_string is DEPRECATED in favor of hex";
  return shift->hex;
}

sub _generate {

  $COUNTER = ($COUNTER + 1) % 0xffffff;

  return pack('N', shift // time)        # 4 byte time
    . $MACHINE                           # 3 byte machine identifier
    . pack('n', $$ % 0xffff)             # 2 byte process id
    . substr pack('V', $COUNTER), 0, 3;  # 3 byte counter
}

1;

=encoding utf8

=head1 NAME

Mango::BSON::ObjectID - Object ID type

=head1 SYNOPSIS

  use Mango::BSON::ObjectID;

  my $oid = Mango::BSON::ObjectID->new('1a2b3c4e5f60718293a4b5c6');
  say $oid->to_epoch;

=head1 DESCRIPTION

L<Mango::BSON::ObjectID> is a container for the BSON object id type used by
L<Mango::BSON>.

=head1 METHODS

L<Mango::BSON::ObjectID> inherits all methods from L<Mojo::Base> and
implements the following new ones.

=head2 from_epoch

  my $oid = $oid->from_epoch(1359840145);

This method is DEPRECATED. And there is no replacement. Using the OID to
store a date is a bad practice and has been removed from all MongoDB
drivers. Use a proper BSON::Time instead.

Generate new object id with specific epoch time.

=head2 get_time

  my $epoch = $oid->get_time;

Extract epoch seconds from the object id.

=head2 hex

  my $oid_string = $oid->hex;

Stringify the object id as a string in hexadecimal.

=head2 new

  my $oid = Mango::BSON::ObjectID->new;
  my $oid = Mango::BSON::ObjectID->new('1a2b3c4e5f60718293a4b5c6');

Construct a new L<Mango::BSON::ObjectID> object.

=head2 oid

  my $binray = $oid->oid;

Return the object id in binary form.

=head2 TO_JSON

  my $oid_string = $oid->TO_JSON;

Returns a hexadecimal string. Same as method L</"hex">.

=head2 to_bytes

  my $bytes = $oid->to_bytes;

This method is DEPRECATED. Use L</oid> instead.

Object id in binary form.

=head2 to_epoch

  my $epoch = $oid->to_epoch;

This method is DEPRECATED. Use L</get_time> instead.

Extract epoch seconds from object id.

=head2 to_string

  my $str = $oid->to_string;

This method is DEPRECATED. Use L</hex> instead.

Stringify object id.

=head1 OPERATORS

L<Mango::BSON::ObjectID> overloads the following operators.

=head2 bool

  my $bool = !!$oid;

Always true.

=head2 stringify

  my $str = "$oid";

Alias for L</hex>.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
