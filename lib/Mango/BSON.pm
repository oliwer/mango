package Mango::BSON;
use Mojo::Base -strict;

use Exporter 'import';
our @EXPORT_OK = qw(bson_length encode_cstring);
sub bson_length { length $_[0] < 4 ? undef : unpack 'l<', substr($_[0], 0, 4) }

sub encode_cstring {
  my $str = shift;
  utf8::encode $str;
  return pack 'Z*', $str;
}

1;

=encoding utf8

=head1 NAME

Mango::BSON - Helper module for BSON handle

=head1 SYNOPSIS

  The module provides only helpers. Decoding/encondig are performed by L<BSON> Module

=head1 FUNCTIONS

=head2 bson_length

  my $len = bson_length $bson;

Check BSON length prefix.

=head2 encode_cstring

  my $bytes = encode_cstring $cstring;

Encode cstring.

=head1 SEE ALSO

L<BSON>, L<BSON::XS>, L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
