package Mango::Auth;
use Mojo::Base -base;

has 'mango';

1;

=encoding utf8

=head1 NAME

Mango::Auth - Authentication

=head1 DESCRIPTION

A base class shared by all authentication backends.

=head1 ATTRIBUTES

=head2 mango

The attached L<Mango> instance.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
