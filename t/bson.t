package BSONTest;
use Mojo::Base -base;

has 'something' => sub { {} };

sub TO_JSON { shift->something }

package BSONTest2;
use Mojo::Base 'BSONTest';

sub TO_BSON { {something => shift->something} }

package main;
use Mojo::Base -strict;
# prevent from injecting qr//u modifier implied by a feature enabled by
# Mojolicious 8.50
no feature 'unicode_strings';
no warnings 'portable';  # Mango works on 64bits systems only

use Test::More;
use Mango::BSON ':bson';
use Mojo::ByteStream 'b';
use Mojo::JSON qw(encode_json decode_json);
use Scalar::Util 'dualvar';

# Ordered document
my $doc = bson_doc(a => 1, c => 2, b => 3);
$doc->{d} = 4;
$doc->{e} = 5;
is_deeply [keys %$doc],   [qw(a c b d e)], 'ordered keys';
is_deeply [values %$doc], [qw(1 2 3 4 5)], 'ordered values';
ok exists $doc->{c}, 'value does exist';
is delete $doc->{c}, 2, 'right value';
ok !exists $doc->{x}, 'value does not exist';
is delete $doc->{x}, undef, 'no value';
is_deeply [keys %$doc],   [qw(a b d e)], 'ordered keys';
is_deeply [values %$doc], [qw(1 3 4 5)], 'ordered values';
$doc->{d} = 6;
is_deeply [keys %$doc],   [qw(a b d e)], 'ordered keys';
is_deeply [values %$doc], [qw(1 3 6 5)], 'ordered values';

# Document length prefix
is bson_length("\x05"),                     undef, 'no length';
is bson_length("\x05\x00\x00\x00"),         5,     'right length';
is bson_length("\x05\x00\x00\x00\x00"),     5,     'right length';
is bson_length("\x05\x00\x00\x00\x00\x00"), 5,     'right length';

# Generate object id
is length bson_oid, 24, 'right length';
is bson_oid('510d83915867b405b9000000')->to_epoch, 1359840145,
  'right epoch time';
my $oid = bson_oid->from_epoch(1359840145);
is $oid->to_epoch, 1359840145, 'right epoch time';
isnt $oid, bson_oid->from_epoch(1359840145), 'different object ids';

# Generate Time
is length bson_time, length(time) + 3, 'right length';
is length int bson_time->to_epoch, length time, 'right length';
is substr(bson_time->to_epoch, 0, 5), substr(time, 0, 5), 'same start';
is bson_time(1360626536748), 1360626536748, 'right epoch milliseconds';
is bson_time(1360626536748)->to_epoch, 1360626536.748, 'right epoch seconds';
is bson_time(1360626536748)->to_datetime, '2013-02-11T23:48:56.748Z',
  'right format';
is bson_time(-28731600 * 1000)->to_datetime, '1969-02-02T11:00:00Z',
  'Before epoch: Boris Karloff death';
is bson_time(-4890694522 * 1000)->to_datetime, '1815-01-08T17:44:38Z',
  'Well before epoch: Battle of New Orleans';

# Empty document
my $bson = bson_encode {};
is_deeply bson_decode($bson), {}, 'successful roundtrip';

# Minimal document roundtrip
my $bytes = "\x05\x00\x00\x00\x00";
$doc = bson_decode($bytes);
is_deeply [keys %$doc], [], 'empty document';
is_deeply $doc, {}, 'empty document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Empty key and value
$bytes = "\x0c\x00\x00\x00\x02\x00\x01\x00\x00\x00\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {'' => ''}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Incomplete document
is bson_decode("\x05\x00\x00\x00"), undef, 'no result';
is bson_decode("\x05\x00\x00"),     undef, 'no result';
is bson_decode("\x05\x00"),         undef, 'no result';
is bson_decode("\x05"),             undef, 'no result';

# Nested document roundtrip
$bytes = "\x10\x00\x00\x00\x03\x6e\x6f\x6e\x65\x00\x05\x00\x00\x00\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {none => {}}, 'empty nested document';
is bson_encode($doc), $bytes, 'successful roundtrip for hash';
is bson_encode(bson_doc(none => {})), $bytes,
  'successful roundtrip for document';

# Document roundtrip with "0" in key
is_deeply bson_decode(bson_encode {n0ne => 'n0ne'}), bson_doc(n0ne => 'n0ne'),
  'successful roundtrip';

# String roundtrip
$bytes = "\x1b\x00\x00\x00\x02\x74\x65\x73\x74\x00\x0c\x00\x00\x00\x68\x65"
  . "\x6c\x6c\x6f\x20\x77\x6f\x72\x6c\x64\x00\x00";
$doc = bson_decode($bytes);
is $doc->{test}, 'hello world', 'right value';
is_deeply [keys %$doc], ['test'], 'one element';
is_deeply $doc, {test => 'hello world'}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
$doc = bson_decode(bson_encode {foo => 'i ♥ mojolicious'});
is $doc->{foo}, 'i ♥ mojolicious', 'successful roundtrip';

# Array
$bytes
  = "\x11\x00\x00\x00\x04\x65\x6d\x70\x74\x79\x00\x05\x00\x00\x00\x00\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {empty => []}, 'empty array';

# Array roundtrip
$bytes
  = "\x11\x00\x00\x00\x04\x65\x6d\x70\x74\x79\x00\x05\x00\x00\x00\x00\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {empty => []}, 'empty array';
is bson_encode($doc), $bytes, 'successful roundtrip';
$bytes
  = "\x33\x00\x00\x00\x04\x66\x69\x76\x65\x00\x28\x00\x00\x00\x10\x30\x00\x01"
  . "\x00\x00\x00\x10\x31\x00\x02\x00\x00\x00\x10\x32\x00\x03\x00\x00\x00\x10"
  . "\x33\x00\x04\x00\x00\x00\x10\x34\x00\x05\x00\x00\x00\x00\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {five => [1, 2, 3, 4, 5]}, 'array with five elements';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Timestamp roundtrip
$bytes = "\x13\x00\x00\x00\x11\x74\x65\x73\x74\x00\x14\x00\x00\x00\x04\x00\x00"
  . "\x00\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{test}, 'Mango::BSON::Timestamp', 'right class';
is $doc->{test}->seconds,   4,  'right seconds';
is $doc->{test}->increment, 20, 'right increment';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Double roundtrip
$bytes = "\x14\x00\x00\x00\x01\x68\x65\x6c\x6c\x6f\x00\x00\x00\x00\x00\x00\x00"
  . "\xf8\x3f\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {hello => 1.5}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
$doc = bson_decode(bson_encode {test => -1.5});
is $doc->{test}, -1.5, 'successful roundtrip';

# Check that string 'nan' is encoded correctly (and *not* as not-a-number
# floating point)
$bytes = "\x14\x00\x00\x00\x02\x68\x65\x6c\x6c\x6f\x00\x04\x00\x00\x00\x6e\x61"
  . "\x6e\x00\x00";
is bson_encode({hello => 'nan'}), $bytes, 'right string-nan encoding';

# Double inf roundtrip
$bytes = "\x14\x00\x00\x00\x01\x68\x65\x6c\x6c\x6f\x00\x00\x00\x00\x00\x00\x00"
  . "\xf0\x7f\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {hello => 0+'iNf'}, 'right double inf document';
is bson_encode($doc), $bytes, 'successful double inf roundtrip';

# Check that string 'inf' is encoded correctly (and *not* as infinity
# floating point)
$bytes = "\x14\x00\x00\x00\x02\x68\x65\x6c\x6c\x6f\x00\x04\x00\x00\x00\x69\x6e"
  . "\x66\x00\x00";
is bson_encode({hello => 'inf'}), $bytes, 'right string-inf encoding';

# Double -inf roundtrip
$bytes = "\x14\x00\x00\x00\x01\x68\x65\x6c\x6c\x6f\x00\x00\x00\x00\x00\x00\x00"
  . "\xf0\xff\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {hello => 0+'-iNf'}, 'right double -inf document';
is bson_encode($doc), $bytes, 'successful double -inf roundtrip';

# Check that string '-inf' is encoded correctly (and *not* as minus infinity
# floating point)
$bytes = "\x15\x00\x00\x00\x02\x68\x65\x6c\x6c\x6f\x00\x05\x00\x00\x00\x2d\x69\x6e"
  . "\x66\x00\x00";
is bson_encode({hello => '-inf'}), $bytes, 'right string-inf encoding';

# Check explicit double serializations
$bytes = "\x10\x00\x00\x00\x01\x78\x00\x00\x00\x00\x00\x00\x00\x37\x40\x00";
is bson_encode({x => bson_double(23.0)}), $bytes, 'encode double to double';
is bson_encode({x => bson_double(23)}), $bytes, 'encode int to double';
is bson_encode({x => bson_double("23")}), $bytes, 'encode string to double';

# Int32 roundtrip
$bytes = "\x0f\x00\x00\x00\x10\x6d\x69\x6b\x65\x00\x64\x00\x00\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {mike => 100}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
$doc = bson_decode(bson_encode {test => -100});
is $doc->{test}, -100, 'successful roundtrip';

# Check explicit Int32 serializations
$bytes = "\x0c\x00\x00\x00\x10\x78\x00\x33\x77\xaa\x55\x00";
is bson_encode({x => bson_int32(0x55aa7733)}), $bytes, 'encode int to Int32';
is bson_encode({x => bson_int32(1437234995)}), $bytes, 'encode int to Int32';
is bson_encode({x => bson_int32(1437234995.3)}), $bytes, 'encode float to Int32 (round down)';
is bson_encode({x => bson_int32("1437234995")}), $bytes, 'encode string to Int32';
is bson_encode({x => bson_int32(0x155aa7733)}), $bytes, 'encode Int64 to Int32 (truncate)';
$bytes = "\x0c\x00\x00\x00\x10\x78\x00\xfe\xff\xff\xff\x00";
is bson_encode({x => bson_int32(0xfffffffe)}), $bytes, 'encode large int to Int32';
is bson_encode({x => bson_int32(-2)}), $bytes, 'encode negative int to Int32';

# Int64 roundtrip
$bytes = "\x13\x00\x00\x00\x12\x6d\x69\x6b\x65\x00\x01\x00\x00\x80\x00\x00\x00"
  . "\x00\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {mike => 2147483649}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
$doc = bson_decode(bson_encode {test => -2147483648});
is $doc->{test}, -2147483648, 'successful roundtrip';

# Check explicit Int64 serializations
$bytes = "\x10\x00\x00\x00\x12\x78\x00\x33\x77\xaa\x55\x00\x00\x00\x00\x00";
is bson_encode({x => bson_int64(0x55aa7733)}), $bytes, 'encode int to Int64';
is bson_encode({x => bson_int64(1437234995)}), $bytes, 'encode int to Int64';
is bson_encode({x => bson_int64(1437234995.3)}), $bytes, 'encode float to Int64 (round down)';
is bson_encode({x => bson_int64("1437234995")}), $bytes, 'encode string to Int64';
$bytes = "\x10\x00\x00\x00\x12\x78\x00\x33\x77\xaa\x55\x01\x00\x00\x00\x00";
is bson_encode({x => bson_int64(0x155aa7733)}), $bytes, 'encode int64 to Int64 (truncate)';
$bytes = "\x10\x00\x00\x00\x12\x78\x00\xfe\xff\xff\xff\xff\xff\xff\xff\x00";
is bson_encode({x => bson_int64(0xfffffffffffffffe)}), $bytes, 'encode large int to Int64';
is bson_encode({x => bson_int64(-2)}), $bytes, 'encode negative int to Int64';

# Boolean roundtrip
$bytes = "\x0c\x00\x00\x00\x08\x74\x72\x75\x65\x00\x01\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {true => bson_true()}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
$bytes = "\x0d\x00\x00\x00\x08\x66\x61\x6c\x73\x65\x00\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {false => bson_false()}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Null roundtrip
$bytes = "\x0b\x00\x00\x00\x0a\x74\x65\x73\x74\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {test => undef}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Max key roundtrip
$bytes = "\x0b\x00\x00\x00\x7f\x74\x65\x73\x74\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {test => bson_max()}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Min key roundtrip
$bytes = "\x0b\x00\x00\x00\xff\x74\x65\x73\x74\x00\x00";
$doc   = bson_decode($bytes);
is_deeply $doc, {test => bson_min()}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Object id roundtrip
my $id = '000102030405060708090a0b';
$bytes = "\x16\x00\x00\x00\x07\x6f\x69\x64\x00\x00"
  . "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{oid}, 'Mango::BSON::ObjectID', 'right class';
is $doc->{oid}->to_epoch, 66051, 'right epoch time';
is_deeply $doc, {oid => $id}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Regex roundtrip
$bytes
  = "\x12\x00\x00\x00\x0b\x72\x65\x67\x65\x78\x00\x61\x2a\x62\x00\x69\x00\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {regex => qr/a*b/i}, 'right document';
like 'AAB',  $doc->{regex}, 'regex works';
like 'ab',   $doc->{regex}, 'regex works';
unlike 'Ax', $doc->{regex}, 'regex works';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Code roundtrip
$bytes = "\x1c\x00\x00\x00\x0d\x66\x6f\x6f\x00\x0e\x00\x00\x00\x76\x61\x72\x20"
  . "\x66\x6f\x6f\x20\x3d\x20\x32\x33\x3b\x00\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Code', 'right class';
is_deeply $doc, {foo => bson_code('var foo = 23;')}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Code with scope roundtrip
$bytes
  = "\x32\x00\x00\x00\x0f\x66\x6f\x6f\x00\x24\x00\x00\x00\x0e\x00\x00\x00\x76"
  . "\x61\x72\x20\x66\x6f\x6f\x20\x3d\x20\x32\x34\x3b\x00\x12\x00\x00\x00\x02\x66"
  . "\x6f\x6f\x00\x04\x00\x00\x00\x62\x61\x72\x00\x00\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Code', 'right class';
is_deeply $doc, {foo => bson_code('var foo = 24;')->scope({foo => 'bar'})},
  'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Time roundtrip
$bytes = "\x14\x00\x00\x00\x09\x74\x6f\x64\x61\x79\x00\x4e\x61\xbc\x00\x00\x00"
  . "\x00\x00\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{today}, 'Mango::BSON::Time', 'right class';
is_deeply $doc, {today => bson_time(12345678)}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
is_deeply bson_decode(bson_encode({time => bson_time(1360627440269)})),
  {time => 1360627440269}, 'successful roundtrip';

# Generic binary roundtrip
$bytes = "\x14\x00\x00\x00\x05\x66\x6f\x6f\x00\x05\x00\x00\x00\x00\x31\x32\x33"
  . "\x34\x35\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Binary', 'right class';
is $doc->{foo}->type, 'generic', 'right type';
is_deeply $doc, {foo => bson_bin('12345')}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Function binary roundtrip
$bytes = "\x14\x00\x00\x00\x05\x66\x6f\x6f\x00\x05\x00\x00\x00\x01\x31\x32\x33"
  . "\x34\x35\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Binary', 'right class';
is $doc->{foo}->type, 'function', 'right type';
is_deeply $doc, {foo => bson_bin('12345')->type('function')}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# MD5 binary roundtrip
$bytes = "\x14\x00\x00\x00\x05\x66\x6f\x6f\x00\x05\x00\x00\x00\x05\x31\x32\x33"
  . "\x34\x35\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Binary', 'right class';
is $doc->{foo}->type, 'md5', 'right type';
is_deeply $doc, {foo => bson_bin('12345')->type('md5')}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# UUID binary roundtrip
$bytes = "\x14\x00\x00\x00\x05\x66\x6f\x6f\x00\x05\x00\x00\x00\x04\x31\x32\x33"
  . "\x34\x35\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Binary', 'right class';
is $doc->{foo}->type, 'uuid', 'right type';
is_deeply $doc, {foo => bson_bin('12345')->type('uuid')}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# User defined binary roundtrip
$bytes = "\x14\x00\x00\x00\x05\x66\x6f\x6f\x00\x05\x00\x00\x00\x80\x31\x32\x33"
  . "\x34\x35\x00";
$doc = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Binary', 'right class';
is $doc->{foo}->type, 'user_defined', 'right type';
is_deeply $doc, {foo => bson_bin('12345')->type('user_defined')},
  'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Pre-encoded BSON document roundtrip
my $raw = bson_raw bson_encode {bar => 'baz'};
is_deeply bson_decode(bson_encode $raw), {bar => 'baz'},
  'successful roundtrip';
is_deeply bson_decode(bson_encode {foo => $raw}), {foo => {bar => 'baz'}},
  'successful roundtrip';
is_deeply bson_decode(bson_encode {foo => [$raw]}), {foo => [{bar => 'baz'}]},
  'successful roundtrip';

# DBRef roundtrip
$bytes
  = "\x31\x00\x00\x00\x03\x64\x62\x72\x65\x66\x00\x25\x00\x00\x00\x07\x24\x69"
  . "\x64\x00\x52\x51\x39\xd8\x58\x67\xb4\x57\x14\x02\x00\x00\x02\x24\x72\x65"
  . "\x66\x00\x05\x00\x00\x00\x74\x65\x73\x74\x00\x00\x00";
$doc = bson_decode($bytes);
is $doc->{dbref}{'$ref'}, 'test', 'right collection name';
is $doc->{dbref}{'$id'}->to_string, '525139d85867b45714020000',
  'right object id';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Unicode roundtrip
$bytes = "\x21\x00\x00\x00\x02\xe2\x98\x83\x00\x13\x00\x00\x00\x49\x20\xe2\x99"
  . "\xa5\x20\x4d\x6f\x6a\x6f\x6c\x69\x63\x69\x6f\x75\x73\x21\x00\x00";
$doc = bson_decode($bytes);
is_deeply $doc, {'☃' => 'I ♥ Mojolicious!'}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';

# Object stringifies to "1"
$bytes = "\x10\x00\x00\x00\x05\x66\x6f\x6f\x00\x01\x00\x00\x00\x00\x31\x00";
$doc   = bson_decode($bytes);
isa_ok $doc->{foo}, 'Mango::BSON::Binary', 'right class';
is $doc->{foo}->type, 'generic', 'right type';
is_deeply $doc, {foo => bson_bin('1')}, 'right document';
is bson_encode($doc), $bytes, 'successful roundtrip';
is bson_bin('1'), '1', 'right result';

# Blessed reference
$bytes = bson_encode {test => b('test')};
is_deeply bson_decode($bytes), {test => 'test'}, 'successful roundtrip';

# Blessed reference with TO_JSON method
$bytes = bson_encode({test => BSONTest->new});
is_deeply bson_decode($bytes), {test => {}}, 'successful roundtrip';
$bytes = bson_encode(
  {
    test => BSONTest->new(
      something => {just => 'works'},
      else      => {not  => 'working'}
    )
  }
);
is_deeply bson_decode($bytes), {test => {just => 'works'}},
  'successful roundtrip';

# Blessed reference with TO_BSON method
$bytes = bson_encode({test => BSONTest2->new});
is_deeply bson_decode($bytes), {test => {something => {}}},
  'successful roundtrip';
$bytes = bson_encode(
  {
    test => BSONTest2->new(
      something => {just => 'works'},
      else      => {not  => 'working'}
    )
  }
);
is_deeply bson_decode($bytes), {test => {something => {just => 'works'}}},
  'successful roundtrip';

# Boolean shortcut
is_deeply bson_decode(bson_encode({true => \1})), {true => bson_true},
  'encode true boolean from constant reference';
is_deeply bson_decode(bson_encode({false => \0})), {false => bson_false},
  'encode false boolean from constant reference';
$bytes = 'some true value';
is_deeply bson_decode(bson_encode({true => \!!$bytes})), {true => bson_true},
  'encode true boolean from double negated reference';
is_deeply bson_decode(bson_encode({true => \$bytes})), {true => bson_true},
  'encode true boolean from reference';
$bytes = '';
is_deeply bson_decode(bson_encode({false => \!!$bytes})),
  {false => bson_false}, 'encode false boolean from double negated reference';
is_deeply bson_decode(bson_encode({false => \$bytes})), {false => bson_false},
  'encode false boolean from reference';

# Mojo::JSON booleans
is_deeply bson_decode(bson_encode {test => Mojo::JSON->true}),
  {test => bson_true}, 'encode true boolean from Mojo::JSON';
is_deeply bson_decode(bson_encode {test => Mojo::JSON->false}),
  {test => bson_false}, 'encode false boolean from Mojo::JSON';

# Upgraded numbers
my $num = 3;
my $str = "$num";
is bson_encode({test => [$num, $str]}),
    "\x20\x00\x00\x00\x04\x74\x65\x73\x74"
  . "\x00\x15\x00\x00\x00\x10\x30\x00\x03\x00\x00\x00\x02\x31\x00\x02\x00\x00"
  . "\x00\x33\x00\x00\x00", 'upgraded number detected';
$num = 1.5;
$str = "$num";
is bson_encode({test => [$num, $str]}),
    "\x26\x00\x00\x00\x04\x74\x65\x73\x74"
  . "\x00\x1b\x00\x00\x00\x01\x30\x00\x00\x00\x00\x00\x00\x00\xf8\x3f\x02\x31"
  . "\x00\x04\x00\x00\x00\x31\x2e\x35\x00\x00\x00", 'upgraded number detected';
$str = '0 but true';
$num = 1 + $str;
is bson_encode({test => [$num, $str]}),
    "\x29\x00\x00\x00\x04\x74\x65\x73\x74\x00\x1e\x00\x00\x00\x10\x30\x00\x01"
  . "\x00\x00\x00\x02\x31\x00\x0b\x00\x00\x00\x30\x20\x62\x75\x74\x20\x74\x72"
  . "\x75\x65\x00\x00\x00", 'upgraded number detected';

# Upgraded string
$str = "bar";
{ no warnings 'numeric'; $num = 23 + $str }
is bson_encode({test => [$num, $str]}),
    "\x26\x00\x00\x00\x04\x74\x65\x73\x74\x00\x1b\x00\x00\x00\x01\x30\x00\x00"
  . "\x00\x00\x00\x00\x00\x37\x40\x02\x31\x00\x04\x00\x00\x00\x62\x61\x72\x00"
  . "\x00\x00", 'upgraded string detected';

# dualvar
my $dual = dualvar 23, 'twenty three';
is bson_encode({test => $dual}),
  "\x1c\x00\x00\x00\x02\x74\x65\x73\x74\x00\x0d\x00\x00\x00\x74\x77\x65\x6e"
  . "\x74\x79\x20\x74\x68\x72\x65\x65\x00\x00", 'dualvar stringified';

# Ensure numbers and strings are not upgraded
my $mixed = {test => [3, 'three', '3', 0, "0"]};
$bson
  = "\x3d\x00\x00\x00\x04\x74\x65\x73\x74\x00\x32\x00\x00\x00\x10\x30\x00"
  . "\x03\x00\x00\x00\x02\x31\x00\x06\x00\x00\x00\x74\x68\x72\x65\x65\x00\x02"
  . "\x32\x00\x02\x00\x00\x00\x33\x00\x10\x33\x00\x00\x00\x00\x00\x02\x34\x00"
  . "\x02\x00\x00\x00\x30\x00\x00\x00";
is bson_encode($mixed), $bson, 'all have been detected correctly';
is bson_encode($mixed), $bson, 'all have been detected correctly again';

# "inf" and "nan"
is_deeply bson_decode(bson_encode {test => [9**9**9]}), {test => [9**9**9]},
  'successful roundtrip';
is_deeply bson_decode(bson_encode {test => [-sin(9**9**9)]}),
  {test => [-sin(9**9**9)]}, 'successful roundtrip';

# Time to JSON
is encode_json({time => bson_time(1360626536748)}), '{"time":1360626536748}',
  'right JSON';
is encode_json({time => bson_time('1360626536748')}),
  '{"time":1360626536748}', 'right JSON';

# Binary to JSON
is encode_json({bin => bson_bin('Hello World!')}),
  '{"bin":"SGVsbG8gV29ybGQh"}', 'right JSON';

# DBRef to JSON
my $json = encode_json(
  {dbref => bson_dbref('test', bson_oid('525139d85867b45714020000'))} );
$json = decode_json($json);
is $json->{dbref}{'$ref'}, 'test', 'dbref $ref in JSON';
is $json->{dbref}{'$id'}, '525139d85867b45714020000', 'dbref $id in JSON';

# Validate object id
is bson_oid('123456789012345678abcdef'), '123456789012345678abcdef',
  'valid object id';
is bson_oid('123456789012345678ABCDEF'), '123456789012345678abcdef',
  'valid object id';
eval { bson_oid('123456789012345678abcde') };
like $@, qr/Invalid object id "123456789012345678abcde"/,
  'object id too short';
eval { bson_oid('123456789012345678abcdeff') };
like $@, qr/Invalid object id "123456789012345678abcdeff"/,
  'object id too long';
eval { bson_oid('123456789012345678abcdgf') };
like $@, qr/Invalid object id "123456789012345678abcdgf"/, 'invalid object id';
eval { bson_oid(0) };
like $@, qr/Invalid object id "0"/, 'invalid object id';

done_testing();
