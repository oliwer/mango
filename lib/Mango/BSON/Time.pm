package Mango::BSON::Time;
use Mojo::Base -base;
use overload bool => sub {1}, '""' => sub { shift->to_string }, fallback => 1;

use Mojo::Date;
use Time::HiRes 'time';

sub new { shift->SUPER::new(time => shift // int(time * 1000)) }

sub TO_JSON { 0 + shift->{time} }

sub to_datetime { Mojo::Date->new->epoch(shift->to_epoch)->to_datetime }

sub to_epoch { shift->to_string / 1000 }

sub to_string { shift->{time} }

1;

=encoding utf8

=head1 NAME

Mango::BSON::Time - Datetime type

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
