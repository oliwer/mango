package Mango::BSON::Time;
use Mojo::Base -base;
use overload bool => sub {1}, '""' => sub { shift->epoch }, fallback => 1;

use Mojo::Date;
use Mojo::Util 'deprecated';
use Time::HiRes 'time';

sub new {
  # Make sure people are using bson_time
  if ( (caller)[0] !~ /^Mango::/ ) {
    warn "You should never use the Mango::BSON::Time constructor ".
         "directly. Use bson_time from Mango::BSON instead.";
  }

  return shift->SUPER::new(time => shift // int(time * 1000));
}

sub TO_JSON { shift->as_iso8601 }

# Old API

sub to_datetime {
  deprecated "to_datetime is DEPRECATED in favor of as_iso8601";
  Mojo::Date->new(shift->{time} / 1000)->to_datetime;
}

sub to_epoch {
  deprecated "to_epoch is DEPRECATED in favor of epoch";
  shift->{time} / 1000;
}

sub to_string {
  deprecated "to_string is DEPRECATED in favor of value";
  shift->{time};
}

# BSON API

sub as_iso8601 { Mojo::Date->new(shift->{time} / 1000)->to_datetime }

sub epoch { int( shift->{time} / 1000 ) }

sub value {
  my ($self, $new) = @_;
  defined $new ? $self->{time} = $new : $self->{time};
}

1;

=encoding utf8

=head1 NAME

Mango::BSON::Time - Datetime type

=head1 SYNOPSIS

  use Mango::BSON::Time;

  my $time = Mango::BSON::Time->new(time * 1000);
  say $time->epoch;

=head1 DESCRIPTION

L<Mango::BSON::Time> is a container for the BSON datetime type used by
L<Mango::BSON>.

=head1 ATTRIBUTES

=head2 value

An integer representing milliseconds since the Unix epoch.

=head1 METHODS

L<Mango::BSON::Time> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 new

  my $time = Mango::BSON::Time->new;
  my $time = Mango::BSON::Time->new(time * 1000);

Construct a new L<Mango::BSON::Time> object.

=head2 TO_JSON

  my $num = $time->TO_JSON;

Return the time represented as a ISO 8601 string.

Up to v1.29, this used to return the numeric representation of time in
milliseconds.

=head2 as_iso8601

  my $str = $time->as_iso8601;

Returns the C<value> as an ISO-8601 formatted string of the form
C<YYYY-MM-DDThh:mm:ss.sssZ>. The fractional seconds will be omitted if
they are zero.

=head2 epoch

  my $epoch = $time->epoch;

Returns the number of seconds since the epoch.

=head2 to_datetime

  my $str = $time->to_datetime;

This method is DEPRECATED. Use L</"as_iso8601"> instead.

Convert time to L<RFC 3339|http://tools.ietf.org/html/rfc3339> date and time.

=head2 to_epoch

  my $epoch = $time->to_epoch;

This method is DEPRECATED. Use L</"epoch"> instead. If you need the extra
floating points, use C<$time->value / 1000>.

Convert time to floating seconds since the epoch.

=head2 to_string

  my $str = $time->to_string;

This method is DEPRECATED. Use L</"value"> instead.

Stringify time.

=head1 OPERATORS

L<Mango::BSON::Time> overloads the following operators.

=head2 bool

  my $bool = !!$time;

Always true.

=head2 stringify

  my $str = "$time";

Alias for L</epoch>.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
