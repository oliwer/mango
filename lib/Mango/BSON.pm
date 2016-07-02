package Mango::BSON;
use Mojo::Base -strict;

use re 'regexp_pattern';
use Carp qw(carp croak);
use Exporter 'import';
use Mango::BSON::Binary;
use Mango::BSON::Code;
use Mango::BSON::Document;
use Mango::BSON::Number;
use Mango::BSON::ObjectID;
use Mango::BSON::Time;
use Mango::BSON::Timestamp;
use Mojo::JSON;
use Mojo::Util 'deprecated';
use Scalar::Util 'blessed';

my @BSON = qw(
  bson_bin bson_bytes bson_code bson_dbref bson_decode bson_doc
  bson_double bson_encode bson_false bson_int32 bson_int64
  bson_length bson_max bson_maxkey bson_min bson_minkey bson_oid
  bson_raw bson_time bson_true bson_ts bson_timestamp
);
our @EXPORT_OK = (@BSON, 'encode_cstring');
our %EXPORT_TAGS = (bson => \@BSON);

# Types
use constant {
  DOUBLE     => "\x01",
  STRING     => "\x02",
  DOCUMENT   => "\x03",
  ARRAY      => "\x04",
  BINARY     => "\x05",
  UNDEFINED  => "\x06",
  OBJECT_ID  => "\x07",
  BOOL       => "\x08",
  DATETIME   => "\x09",
  NULL       => "\x0a",
  REGEX      => "\x0b",
  CODE       => "\x0d",
  CODE_SCOPE => "\x0f",
  INT32      => "\x10",
  TIMESTAMP  => "\x11",
  INT64      => "\x12",
  MIN_KEY    => "\xff",
  MAX_KEY    => "\x7f"
};

# Binary subtypes
use constant {
  BINARY_GENERIC      => "\x00",
  BINARY_FUNCTION     => "\x01",
  BINARY_UUID         => "\x04",
  BINARY_MD5          => "\x05",
  BINARY_USER_DEFINED => "\x80"
};

# The pack() format to use for each numeric type
my %num_pack_fmt = (
  DOUBLE() => 'd<',
  INT32()  => 'l<',
  INT64()  => 'q<'
);

# Reuse boolean singletons
my $FALSE = Mojo::JSON->false;
my $TRUE  = Mojo::JSON->true;
my $BOOL  = blessed $TRUE;

my $MAXKEY = bless {}, 'Mango::BSON::_MaxKey';
my $MINKEY = bless {}, 'Mango::BSON::_MinKey';

sub bson_bin {
  deprecated "bson_bin is DEPRECATED in favor of bson_bytes";
  return bson_bytes(@_);
}

sub bson_bytes { Mango::BSON::Binary->new(data => shift) }

sub bson_code { Mango::BSON::Code->new(code => shift) }

sub bson_dbref {
  my ($id, $ref) = @_;

  # Check if the arguments are in the right order
  unless ($id =~ /^[a-zA-Z0-9]{24}\z/) {
    carp "The order of the arguments of bson_dbref() has changed ".
         "in Mango 1.30+. Please correct this.";
    ($ref, $id) = ($id, $ref);
  }

  return bson_doc('$ref' => $ref, '$id' => $id);
}

sub bson_decode {
  my $bson = shift;
  return undef unless my $len = bson_length($bson);
  return length $bson == $len ? _decode_doc(\$bson) : undef;
}

sub bson_doc {
  tie my %hash, 'Mango::BSON::Document', @_;
  return \%hash;
}

sub bson_double { Mango::BSON::Number->new(shift, DOUBLE) }

sub bson_encode {
  my $doc = shift;

  # Embedded BSON
  return $doc->{'$bson'} if exists $doc->{'$bson'};

  my $bson = join '',
    map { _encode_value(encode_cstring($_), $doc->{$_}) } keys %$doc;

  # Document ends with null byte
  return pack('l<', length($bson) + 5) . $bson . "\x00";
}

sub bson_false {$FALSE}

sub bson_int32 { Mango::BSON::Number->new(shift, INT32) }

sub bson_int64 { Mango::BSON::Number->new(shift, INT64) }

sub bson_length {
  # This sub will be removed in v2.00
  length $_[0] < 4 ? undef : unpack 'l<', substr($_[0], 0, 4);
}

sub bson_max {
  deprecated "bson_max is DEPRECATED in favor of bson_maxkey";
  return $MAXKEY;
}

sub bson_maxkey { $MAXKEY }

sub bson_min {
  deprecated "bson_min is DEPRECATED in favor of bson_minkey";
  return $MINKEY;
}

sub bson_minkey { $MINKEY }

sub bson_oid { Mango::BSON::ObjectID->new(@_) }

sub bson_raw { bson_doc('$bson' => shift) }

sub bson_time { Mango::BSON::Time->new(@_) }

sub bson_timestamp {
  Mango::BSON::Timestamp->new(seconds => shift, increment => shift);
}

sub bson_ts {
  deprecated "bson_ts is DEPRECATED in favor of bson_timestamp";
  return bson_timestamp(@_);
}

sub bson_true {$TRUE}

sub encode_cstring {
  # This sub will be removed in v2.00
  my $str = shift;
  utf8::encode $str;
  return pack 'Z*', $str;
}

sub _decode_binary {
  my $bsonref = shift;

  my $len = unpack 'l<', substr($$bsonref, 0, 4, '');
  my $subtype = substr $$bsonref, 0, 1, '';
  my $binary = substr $$bsonref, 0, $len, '';

  return bson_bytes($binary)->subtype('function') if $subtype eq BINARY_FUNCTION;
  return bson_bytes($binary)->subtype('md5')      if $subtype eq BINARY_MD5;
  return bson_bytes($binary)->subtype('uuid')     if $subtype eq BINARY_UUID;
  return bson_bytes($binary)->subtype('user_defined')
    if $subtype eq BINARY_USER_DEFINED;
  return bson_bytes($binary)->subtype('generic');
}

sub _decode_cstring {
  my $bsonref = shift;
  my $str = substr $$bsonref, 0, index($$bsonref, "\x00"), '';
  utf8::decode $str;
  substr $$bsonref, 0, 1, '';
  return $str;
}

sub _decode_doc {
  my $bsonref = shift;

  # Every element starts with a type
  my @doc;
  substr $$bsonref, 0, 4, '';
  while (my $type = substr $$bsonref, 0, 1, '') {

    # Null byte (end of document)
    last if $type eq "\x00";

    push @doc, _decode_cstring($bsonref), _decode_value($type, $bsonref);
  }

  return bson_doc(@doc);
}

sub _decode_string {
  my $bsonref = shift;

  my $len = unpack 'l<', substr($$bsonref, 0, 4, '');
  my $str = substr $$bsonref, 0, $len - 1, '';
  utf8::decode $str;
  substr $$bsonref, 0, 1, '';

  return $str;
}

sub _decode_value {
  my ($type, $bsonref) = @_;

  # String
  return _decode_string($bsonref) if $type eq STRING;

  # Object ID
  return bson_oid(unpack 'H*', substr $$bsonref, 0, 12, '')
    if $type eq OBJECT_ID;

  # Double/Int32/Int64
  return unpack 'd<', substr $$bsonref, 0, 8, '' if $type eq DOUBLE;
  return unpack 'l<', substr($$bsonref, 0, 4, '') if $type eq INT32;
  return unpack 'q<', substr($$bsonref, 0, 8, '') if $type eq INT64;

  # Document
  return _decode_doc($bsonref) if $type eq DOCUMENT;

  # Array
  return [values %{_decode_doc($bsonref)}] if $type eq ARRAY;

  # Booleans and Null
  return substr($$bsonref, 0, 1, '') eq "\x00" ? bson_false() : bson_true()
    if $type eq BOOL;
  return undef if $type eq NULL;

  # Time
  return bson_time(unpack 'q<', substr($$bsonref, 0, 8, ''))
    if $type eq DATETIME;

  # Regex
  if ($type eq REGEX) {
    my ($p, $m) = (_decode_cstring($bsonref), _decode_cstring($bsonref));
    croak "invalid regex modifier(s) in 'qr/$p/$m'"
      if length($m) and $m !~ /^[msixpadlun]+\z/;
    # escape $pat to avoid code injection
    return eval "qr/\$p/$m";
  }

  # Binary (with subtypes)
  return _decode_binary($bsonref) if $type eq BINARY;

  # Min/Max
  return bson_minkey() if $type eq MIN_KEY;
  return bson_maxkey() if $type eq MAX_KEY;

  # Code (with and without scope)
  return bson_code(_decode_string($bsonref)) if $type eq CODE;
  if ($type eq CODE_SCOPE) {
    substr $$bsonref, 0, 4, '';
    return bson_code(_decode_string($bsonref))->scope(_decode_doc($bsonref));
  }

  # Timestamp
  return bson_timestamp(
    reverse map({ unpack 'l<', substr($$_, 0, 4, '') } $bsonref, $bsonref))
    if $type eq TIMESTAMP;

  # Undefined - a deprecated type which should not exist anymore
  # but apparently still does: https://github.com/oliwer/mango/issues/1
  return undef if $type eq UNDEFINED;

  # Unknown
  croak 'Unknown BSON type';
}

sub _encode_binary {
  my ($e, $subtype, $value) = @_;
  return BINARY . $e . pack('l<', length $value) . $subtype . $value;
}

sub _encode_object {
  my ($e, $value, $class) = @_;

  # ObjectID
  return OBJECT_ID . $e . $value->oid
    if $class eq 'Mango::BSON::ObjectID';

  # Boolean
  return BOOL . $e . ($value ? "\x01" : "\x00") if $class eq $BOOL;

  # Time
  return DATETIME . $e . pack('q<', $value->{time})
    if $class eq 'Mango::BSON::Time';

  # Max
  return MAX_KEY . $e if $value eq $MAXKEY;

  # Min
  return MIN_KEY . $e if $value eq $MINKEY;

  # Regex
  if ($class eq 'Regexp') {
    my ($p, $m) = regexp_pattern($value);
    return REGEX . $e . encode_cstring($p) . encode_cstring($m);
  }

  # Binary
  if ($class eq 'Mango::BSON::Binary') {
    my $type = $value->type // 'generic';
    my $data = $value->data;
    return _encode_binary($e, BINARY_FUNCTION, $data) if $type eq 'function';
    return _encode_binary($e, BINARY_MD5,      $data) if $type eq 'md5';
    return _encode_binary($e, BINARY_USER_DEFINED, $data)
      if $type eq 'user_defined';
    return _encode_binary($e, BINARY_UUID, $data) if $type eq 'uuid';
    return _encode_binary($e, BINARY_GENERIC, $data);
  }

  # Code
  if ($class eq 'Mango::BSON::Code') {

    # With scope
    if (my $scope = $value->scope) {
      my $code = _encode_string($value->code) . bson_encode($scope);
      return CODE_SCOPE . $e . pack('l<', length $code) . $code;
    }

    # Without scope
    return CODE . $e . _encode_string($value->code);
  }

  # Timestamp
  return TIMESTAMP, $e, map { pack 'l<', $_ } $value->increment,
    $value->seconds
    if $class eq 'Mango::BSON::Timestamp';

  # Number
  if ($class eq 'Mango::BSON::Number') {
    my $t = $value->type;
    return $t . $e . pack($num_pack_fmt{$t}, $value->value);
  }

  # Blessed reference with TO_JSON method
  if (my $sub = $value->can('TO_BSON') // $value->can('TO_JSON')) {
    return _encode_value($e, $value->$sub);
  }

  # Stringify
  return STRING . $e . _encode_string($value);
}

sub _encode_string {
  my $str = shift;
  utf8::encode $str;
  return pack('l<', length($str) + 1) . "$str\x00";
}

sub _encode_value {
  my ($e, $value) = @_;

  # Null
  return NULL . $e unless defined $value;

  # Reference
  if (my $ref = ref $value) {

    # Blessed
    return _encode_object($e, $value, $ref) if blessed $value;

    # Hash (Document)
    return DOCUMENT . $e . bson_encode($value) if $ref eq 'HASH';

    # Array
    if ($ref eq 'ARRAY') {
      my $i = 0;
      return ARRAY . $e . bson_encode(bson_doc(map { $i++ => $_ } @$value));
    }

    # Scalar (boolean shortcut)
    return _encode_object($e, !!$$value, $BOOL) if $ref eq 'SCALAR';
  }

  # Numeric
  if (my $type = Mango::BSON::Number::guess_type($value)) {
    return $type . $e . pack($num_pack_fmt{$type}, $value);
  }

  # String
  return STRING . $e . _encode_string("$value");
}

# Constants
package Mango::BSON::_MaxKey;

package Mango::BSON::_MinKey;

1;

=encoding utf8

=head1 NAME

Mango::BSON - BSON

=head1 SYNOPSIS

  use Mango::BSON ':bson';

  my $bson = bson_encode {
    foo       => 'bar',
    baz       => 0.42,
    unordered => {one => [1, 2, 3], two => bson_time},
    ordered   => bson_doc(one => qr/test/i, two => bson_true)
  };
  my $doc = bson_decode $bson;

=head1 DESCRIPTION

L<Mango::BSON> is a minimalistic implementation of L<http://bsonspec.org>.

In addition to a bunch of custom BSON data types it supports normal Perl data
types like scalar, regular expression, C<undef>, array reference, hash
reference and will try to call the C<TO_BSON> and C<TO_JSON> methods on
blessed references, or stringify them if it doesn't exist. Scalar references
will be used to generate booleans, based on if their values are true or false.

=head1 FUNCTIONS

L<Mango::BSON> implements the following functions, which can be imported
individually or at once with the C<:bson> flag.

=head2 bson_bin

This function is DEPRECATED. Use L</bson_bytes> instead.

head2 bson_bytes

  my $bin = bson_bytes $bytes;

Create new BSON element of the binary type with L<Mango::BSON::Binary>,
defaults to the C<generic> binary subtype.

  # Function
  bson_bytes($bytes)->subtype('function');

  # MD5
  bson_bytes($bytes)->subtype('md5');

  # UUID
  bson_bytes($bytes)->subtype('uuid');

  # User defined
  bson_bytes($bytes)->subtype('user_defined');

=head2 bson_code

  my $code = bson_code 'function () {}';

Create new BSON element of the code type with L<Mango::BSON::Code>.

  # With scope
  bson_code('function () {}')->scope({foo => 'bar'});

=head2 bson_dbref

  my $dbref = bson_dbref $oid, 'test';

Create a new database reference.

WARNING: the order of the arguments has been switched in version 1.30.
The oid comes first now.

  # Longer version
  my $dbref = {'$ref' => 'test', '$id' => $oid};

=head2 bson_decode

  my $doc = bson_decode $bson;

Decode BSON into Perl data structures.

=head2 bson_doc

  my $doc = bson_doc;
  my $doc = bson_doc foo => 'bar', baz => 0.42, yada => {yada => [1, 2, 3]};

Create new BSON document with L<Mango::BSON::Document>, which can also be used
as a generic ordered hash.

  # Order is preserved
  my $hash = bson_doc one => 1, two => 2, three => 3;
  $hash->{four} = 4;
  delete $hash->{two};
  say for keys %$hash;

=head2 bson_double

  my $doc = { foo => bson_double(13.0) };

Force a scalar value to be encoded as a double in MongoDB. Croaks if the
value is incompatible with the double type.

=head2 bson_encode

  my $bson = bson_encode $doc;
  my $bson = bson_encode {};

Encode Perl data structures into BSON.

=head2 bson_false

  my $false = bson_false;

Create new BSON element of the boolean type false.

=head2 bson_int32

  my $doc = { foo => bson_int32(13) };

  # This will die (integer is too big)
  my $doc = { foo => bson_int32(2147483648) };

Force a scalar value to be encoded as a 32 bit integer in MongoDB. Croaks if
the value is incompatible with the int32 type.

=head2 bson_int64

  my $doc = { foo => bson_int64(666) };

Force a scalar value to be encoded as a 64 bit integer in MongoDB. Croaks if
the value is incompatible with the int64 type.

=head2 bson_length

  my $len = bson_length $bson;

This function is DEPRECATED;

Check BSON length prefix.

=head2 bson_max

This function is DEPRECATED. Use L</bson_maxkey> instead.

=head2 bson_maxkey

  my $max_key = bson_maxkey;

Create new BSON element of the max key type.

=head2 bson_min

This function is DEPRECATED. Use L</bson_minkey> instead.

=head2 bson_minkey

  my $min_key = bson_minkey;

Create new BSON element of the min key type.

=head2 bson_oid

  my $oid = bson_oid;
  my $oid = bson_oid '1a2b3c4e5f60718293a4b5c6';

Create new BSON element of the object id type with L<Mango::BSON::ObjectID>,
defaults to generating a new unique object id.

  # Generate object id with specific epoch time
  my $oid = bson_oid->from_epoch(1359840145);

=head2 bson_raw

  my $raw = bson_raw $bson;

Pre-encoded BSON document.

  # Longer version
  my $raw = {'$bson' => $bson};

  # Embed pre-encoded BSON document
  my $first  = bson_encode {foo => 'bar'};
  my $second = bson_encode {test => bson_raw $first};

=head2 bson_time

  my $now  = bson_time;
  my $time = bson_time time * 1000;

Create new BSON element of the UTC datetime type with L<Mango::BSON::Time>,
defaults to milliseconds since the UNIX epoch.

  # "1360626536.748"
  bson_time(1360626536748)->to_epoch;

  # "2013-02-11T23:48:56.748Z"
  bson_time(1360626536748)->to_datetime;

=head2 bson_true

  my $true = bson_true;

Create new BSON element of the boolean type true.

=head2 bson_timestamp

  my $timestamp = bson_ts 23, 24;

Create new BSON element of the timestamp type with L<Mango::BSON::Timestamp>.

=head2 bson_ts

This function is DEPRECATED. Use L</bson_timestamp> instead.

=head2 encode_cstring

  my $bytes = encode_cstring $cstring;

This function is DEPRECATED.

Encode cstring.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
