use Mojo::Base -strict;

use Test::More;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

use Mango;
use Mango::BSON 'bson_oid';
use Mojo::IOLoop;

# Clean up before start
my $mango  = Mango->new($ENV{TEST_ONLINE});
my $gridfs = $mango->db->gridfs;
$gridfs->$_->remove for qw(files chunks);

# Blocking roundtrip
my $writer = $gridfs->writer;
$writer->filename('foo.txt')->content_type('text/plain')
  ->metadata({foo => 'bar'});
ok !$writer->is_closed, 'file has not been closed';
my $oid = $writer->write('hello ')->write('world!')->close;
ok $writer->is_closed, 'file has been closed';
my $reader = $gridfs->reader;
is $reader->tell, 0, 'right position';
$reader->open($oid);
is $reader->filename,     'foo.txt',    'right filename';
is $reader->content_type, 'text/plain', 'right content type';
is $reader->md5, 'fc3ff98e8c6a0d3087d515c0473f8677', 'right checksum';
is_deeply $reader->metadata, {foo => 'bar'}, 'right structure';
is $reader->size,       12,     'right size';
is $reader->chunk_size, 261120, 'right chunk size';
is length $reader->upload_date, length(time) + 3, 'right time format';
my $data;
while (defined(my $chunk = $reader->read)) { $data .= $chunk }
is $reader->tell, 12, 'right position';
is $data, 'hello world!', 'right content';
$data = undef;
$reader->seek(0);
is $reader->tell, 0, 'right position';
$reader->seek(2);
is $reader->tell, 2, 'right position';
while (defined(my $chunk = $reader->read)) { $data .= $chunk }
is $data, 'llo world!', 'right content';
is_deeply $gridfs->list, ['foo.txt'], 'right files';
$gridfs->delete($oid);
is_deeply $gridfs->list, [], 'no files';
is $gridfs->chunks->find->count, 0, 'no chunks left';
$gridfs->$_->drop for qw(files chunks);

# Non-blocking roundtrip
$writer = $gridfs->writer->chunk_size(4);
$writer->filename('foo.txt')->content_type('text/plain')
  ->metadata({foo => 'bar'});
ok !$writer->is_closed, 'file has not been closed';
my ($fail, $result);
my $delay = Mojo::IOLoop->delay(
  sub {
    my $delay = shift;
    $writer->write('he' => $delay->begin);
  },
  sub {
    my ($delay, $err) = @_;
    return $delay->pass($err) if $err;
    $writer->write('llo ' => $delay->begin);
  },
  sub {
    my ($delay, $err) = @_;
    return $delay->pass($err) if $err;
    $writer->write('w'     => $delay->begin);
    $writer->write('orld!' => $delay->begin);
  },
  sub {
    my ($delay, $err) = @_;
    return $delay->pass($err) if $err;
    $writer->close($delay->begin);
  },
  sub {
    my ($delay, $err, $oid) = @_;
    $fail   = $err;
    $result = $oid;
  }
);
$delay->wait;
ok !$fail, 'no error';
ok $writer->is_closed, 'file has been closed';
$reader = $gridfs->reader;
$fail   = undef;
$reader->open(
  $result => sub {
    my ($reader, $err) = @_;
    $fail = $err;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
ok !$fail, 'no error';
is $reader->filename,     'foo.txt',    'right filename';
is $reader->content_type, 'text/plain', 'right content type';
is $reader->md5, 'fc3ff98e8c6a0d3087d515c0473f8677', 'right checksum';
is_deeply $reader->metadata, {foo => 'bar'}, 'right structure';
is $reader->size,       12, 'right size';
is $reader->chunk_size, 4,  'right chunk size';
is length $reader->upload_date, length(time) + 3, 'right time format';
($fail, $data) = ();
my $cb;
$cb = sub {
  my ($reader, $err, $chunk) = @_;
  $fail ||= $err;
  return Mojo::IOLoop->stop unless defined $chunk;
  $data .= $chunk;
  $reader->read($cb);
};
$reader->$cb(undef, '');
Mojo::IOLoop->start;
ok !$fail, 'no error';
is $data, 'hello world!', 'right content';
my ($before, $after);
$fail  = undef;
$delay = Mojo::IOLoop->delay(
  sub { $gridfs->list(shift->begin) },
  sub {
    my ($delay, $err, $names) = @_;
    return $delay->pass($err) if $err;
    $before = $names;
    $gridfs->delete($result => $delay->begin);
  },
  sub {
    my ($delay, $err) = @_;
    return $delay->pass($err) if $err;
    $gridfs->list($delay->begin);
  },
  sub {
    my ($delay, $err, $names) = @_;
    $fail  = $err;
    $after = $names;
  }
);
$delay->wait;
ok !$fail, 'no error';
is_deeply $before, ['foo.txt'], 'right files';
is_deeply $after, [], 'no files';
is $gridfs->chunks->find->count, 0, 'no chunks left';
$gridfs->$_->drop for qw(files chunks);

# Non-blocking roundtrip with promises
if (Mango::PROMISES) {

  $writer = $gridfs->writer->chunk_size(4);
  $writer->filename('foo.txt')->content_type('text/plain')
    ->metadata({foo => 'bar'});
  ok !$writer->is_closed, 'file has not been closed';

  $writer->write_p('he')->then(
    sub {
      $writer->write_p('llo ');
    }
  )->then(
    sub {
      $writer->write_p('w');
    }
  )->then(
    sub {
      $writer->write_p('orld!');
    }
  )->then(
    sub {
      $writer->close_p;
    },
    sub {
      fail("write_p  failed, err: $_[0]");    # should not happen
    }
  )->then(
    sub {
      my $oid = shift;
      ok $writer->is_closed, 'file has been closed - p';
      $result = $oid;
    },
    sub {
      fail("close_p failed, err: $_[0]");     # should not happen
    }
  )->wait;

  $reader = $gridfs->reader;
  $reader->open_p($result)->then(
    sub {
      is $reader->filename,     'foo.txt',    'right filename - p';
      is $reader->content_type, 'text/plain', 'right content type - p';
      is $reader->md5, 'fc3ff98e8c6a0d3087d515c0473f8677', 'right checksum - p';
      is_deeply $reader->metadata, {foo => 'bar'}, 'right structure - p';
      is $reader->size,       12, 'right size - p';
      is $reader->chunk_size, 4,  'right chunk size - p';
      is length $reader->upload_date, length(time) + 3, 'right time format - p';
    },
    sub {
      fail("open_p failed, err: $_[0]");    # should not happen
    }
  )->then(
    sub {
      my ($data, $cb);
      $reader->read_p()->then(
        $cb = sub {
          my $chunk = shift;
          return unless defined $chunk;
          $data .= $chunk;
          $reader->read_p()->then($cb);
        }
      )->then(
        sub {
          is $data, 'hello world!', 'right content - p';
        },
        sub {
          fail("read_p failed, err: $_[0]");    # should not happen
        }
      );
    }
  )->then(
    sub {
      $reader->seek(0);                         # rewind
      $reader->slurp_p();
    }
  )->then(
    sub {
      my $data = shift;
      is $data, 'hello world!', 'right slurped content - p';
    },
    sub {
      fail("slurp_p failed, err: $_[0]");       # should not happen
    }
  )->wait;

  $gridfs->list_p()->then(
    sub {
      my $names = shift;
      is_deeply $names, ['foo.txt'], 'right files - p';

      $gridfs->delete_p($result);
    },
    sub {
      fail("list_p failed, err: $_[0]");        # should not happen
    }
  )->then(
    sub {
      $gridfs->list_p;
    },
    sub {
      fail("delete_p failed, err: $_[0]");      # should not happen
    }
  )->then(
    sub {
      my $names = shift;
      is_deeply $names, [], 'no files - p';

      is $gridfs->chunks->find->count, 0, 'no chunks left - p';
    }
  )->wait;

  $gridfs->$_->drop for qw(files chunks);
}

# Find and slurp versions blocking
my $one
  = $gridfs->writer->chunk_size(1)->filename('test.txt')->write('One1')->close;
is $gridfs->find_version('test.txt', -1), $one, 'right version';
my $two = $gridfs->writer->filename('test.txt')->write('Two')->close;
is $gridfs->find_version('test.txt', -1), $two, 'right version';
is $gridfs->find_version('test.txt', -2), $one, 'right version';
is $gridfs->find_version('test.txt', -3), undef, 'no version';
is_deeply $gridfs->list, ['test.txt'], 'right files';
is $gridfs->find_version('test.txt', 0), $one, 'right version';
is $gridfs->find_version('test.txt', 1), $two, 'right version';
is $gridfs->find_version('test.txt', 2), undef, 'no version';
is $gridfs->reader->open($one)->slurp, 'One1', 'right content';
is $gridfs->reader->open($one)->seek(1)->slurp, 'ne1', 'right content';
is $gridfs->reader->open($two)->slurp, 'Two', 'right content';
is $gridfs->reader->open($two)->seek(1)->slurp, 'wo', 'right content';
$gridfs->$_->drop for qw(files chunks);

# Find and slurp versions non-blocking
$one = $gridfs->writer->filename('test.txt')->write('One')->close;
$two = $gridfs->writer->filename('test.txt')->write('Two')->close;
is_deeply $gridfs->list, ['test.txt'], 'right files';
my @results;
$fail  = undef;
$delay = Mojo::IOLoop->delay(
  sub {
    my $delay = shift;
    $gridfs->find_version(('test.txt', 2) => $delay->begin);
    $gridfs->find_version(('test.txt', 1) => $delay->begin);
    $gridfs->find_version(('test.txt', 0) => $delay->begin);
  },
  sub {
    my ($delay, $three_err, $three, $two_err, $two, $one_err, $one) = @_;
    $fail = $one_err || $two_err || $three_err;
    @results = ($one, $two, $three);
  }
);
$delay->wait;
ok !$fail, 'no error';
is $results[0], $one, 'right version';
is $results[1], $two, 'right version';
is $results[2], undef, 'no version';
my $one_reader = $gridfs->reader;
my $two_reader = $gridfs->reader;
($fail, @results) = ();
$delay = Mojo::IOLoop->delay(
  sub {
    my $delay = shift;
    $one_reader->open($one => $delay->begin);
    $two_reader->open($two => $delay->begin);
  },
  sub {
    my ($delay, $one_err, $two_err) = @_;
    if (my $err = $one_err || $two_err) { return $delay->pass($err) }
    $one_reader->slurp($delay->begin);
    $two_reader->slurp($delay->begin);
  },
  sub {
    my ($delay, $one_err, $one, $two_err, $two) = @_;
    $fail = $one_err || $two_err;
    @results = ($one, $two);
  }
);
$delay->wait;
ok !$fail, 'no error';
is $results[0], 'One', 'right content';
is $results[1], 'Two', 'right content';
$gridfs->$_->drop for qw(files chunks);

# File already closed
$writer = $gridfs->writer;
ok !$writer->is_closed, 'file has not been closed';
$oid = $writer->write('Test')->close;
ok $writer->is_closed, 'file has been closed';
eval { $writer->write('123') };
like $@, qr/^File already closed/, 'right error';
$fail = undef;
$writer->write(
  '123' => sub {
    my ($writer, $err) = @_;
    $fail = $err;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
like $fail, qr/^File already closed/, 'right error';
ok $writer->is_closed, 'file is still closed';
is $writer->close, $oid, 'right result';
($fail, $result) = ();
$writer->close(
  sub {
    my ($writer, $err, $oid) = @_;
    $fail   = $err;
    $result = $oid;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
ok !$fail, 'no error';
is $result, $oid, 'right result';
ok $writer->is_closed, 'file is still closed';
$gridfs->$_->drop for qw(files chunks);

# Big chunks and concurrent readers
$oid = $gridfs->writer->write('x' x 1000000)->close;
($fail, @results) = ();
$delay = Mojo::IOLoop->delay(
  sub {
    my $delay = shift;
    $gridfs->reader->open($oid => $delay->begin(0));
    $gridfs->reader->open($oid => $delay->begin(0));
  },
  sub {
    my ($delay, $reader1, $err1, $reader2, $err2) = @_;
    if (my $err = $err1 || $err2) { return $delay->pass($err) }
    $reader1->slurp($delay->begin);
    $reader2->slurp($delay->begin);
  },
  sub {
    my ($delay, $err1, $data1, $err2, $data2) = @_;
    $fail = $err1 || $err2;
    @results = ($data1, $data2);
  }
);
$delay->wait;
ok !$fail, 'no error';
is $results[0], 'x' x 1000000, 'right content';
is $results[1], 'x' x 1000000, 'right content';
$gridfs->$_->drop for qw(files chunks);

# Open missing file blocking
$oid = bson_oid;
eval { $gridfs->reader->open($oid) };
like $@, qr/^$oid does not exist/, 'right error';

# Open missing file non-blocking
$fail = undef;
$gridfs->reader->open(
  $oid => sub {
    my ($reader, $err) = @_;
    $fail = $err;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
like $fail, qr/^$oid does not exist/, 'right error';

done_testing();
