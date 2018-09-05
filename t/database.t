use Mojo::Base -strict;

use Test::More;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

use Mango;
use Mango::BSON qw(bson_code bson_dbref);
use Mojo::IOLoop;

# Run command blocking
my $mango = Mango->new($ENV{TEST_ONLINE});
my $db    = $mango->db;
ok $db->command('getnonce')->{nonce}, 'command was successful';

# Run command non-blocking
my ($fail, $result);
$db->command(
  'getnonce' => sub {
    my ($db, $err, $doc) = @_;
    $fail   = $err;
    $result = $doc->{nonce};
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
ok !$fail, 'no error';
ok $result, 'command was successful';

# Run command with promises
if (Mango::PROMISES) {
  $db->command_p('getnonce')->then(
    sub {
      my $doc = shift;
      ok $doc->{nonce}, 'command_p was successful';
    },
    sub {
      fail("command_p failed, err: $_[0]");    # should not happen
    }
  )->wait;
}

# Write concern
my $mango2  = Mango->new->w(2)->wtimeout(5000);
my $concern = $mango2->db('test')->build_write_concern;
is $concern->{w},        2,    'right w value';
is $concern->{wtimeout}, 5000, 'right wtimeout value';

# Get database statistics blocking
ok exists $db->stats->{objects}, 'has objects';

# Get database statistics non-blocking
($fail, $result) = ();
$db->stats(
  sub {
    my ($db, $err, $stats) = @_;
    $fail   = $err;
    $result = $stats;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
ok !$fail, 'no error';
ok exists $result->{objects}, 'has objects';

# Get database statistics with promises
if (Mango::PROMISES) {
  $db->stats_p->then(
    sub {
      my $stats = shift;
      ok exists $stats->{objects}, 'stats_p: has objects';
    },
    sub {
      fail("stats_p failed, err: $_[0]");    # should not happen
    }
  )->wait;
}

# List collections
my $collection = $db->collection('database_test');
$collection->insert({test => 1});
ok @{$db->list_collections->all} > 0, 'found collections';
is $db->list_collections(filter => { name => qr{base_test} })->all->[0]->{name},
  'database_test', 'found collection using filtering';
# non-blocking mode is tested implicitely by collection_names below

# Get collection names blocking
ok grep { $_ eq 'database_test' } @{$db->collection_names}, 'found collection';
$collection->drop;

# Get collection names non-blocking
$collection->insert({test => 1});
($fail, $result) = ();
$db->collection_names(
  sub {
    my ($db, $err, $names) = @_;
    $fail   = $err;
    $result = $names;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
ok !$fail, 'no error';
ok grep { $_ eq 'database_test' } @$result, 'found collection';
$collection->drop;

# Get collection names with promises
if (Mango::PROMISES) {
  $collection->insert({test => 1});
  $db->collection_names_p->then(
    sub {
      my $names = shift;
      ok grep { $_ eq 'database_test' } @$names, 'collection_names_p: found collection';
    },
    sub {
      fail("collection_names_p failed, err: $_[0]");    # should not happen
    }
  );
  $collection->drop;
}

# Dereference blocking
my $oid = $collection->insert({test => 23});
is $db->dereference(bson_dbref('database_test', $oid))->{test}, 23,
  'right result';
$collection->drop;

# Dereference non-blocking
$oid = $collection->insert({test => 23});
($fail, $result) = ();
$db->dereference(
  bson_dbref('database_test', $oid) => sub {
    my ($db, $err, $doc) = @_;
    $fail   = $err;
    $result = $doc;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
ok !$fail, 'no error';
is $result->{test}, 23, 'right result';
$collection->drop;

# Dereference with promises
if (Mango::PROMISES) {
  $oid = $collection->insert({test => 23});
  $db->dereference_p(bson_dbref('database_test', $oid))->then(
    sub {
      my $doc = shift;
      is $doc->{test}, 23, 'dereference_p: right result';
    },
    sub {
      fail("dereference_p failed, err: $_[0]");    # should not happen
    }
  )->wait;
  $collection->drop;
}

# Interrupted blocking command
my $loop = $mango->ioloop;
my $id   = $loop->server((address => '127.0.0.1') => sub { $_[1]->close });
my $port = $loop->acceptor($id)->handle->sockport;
$mango = Mango->new("mongodb://localhost:$port")->ioloop($loop);
eval { $mango->db->command('getnonce') };
like $@, qr/Premature connection close/, 'right error';
$mango->ioloop->remove($id);

# Interrupted non-blocking command
$id = Mojo::IOLoop->server((address => '127.0.0.1') => sub { $_[1]->close });
$port = Mojo::IOLoop->acceptor($id)->handle->sockport;
$mango = Mango->new("mongodb://localhost:$port");
$fail  = undef;
$mango->db->command(
  'getnonce' => sub {
    my ($db, $err) = @_;
    $fail = $err;
    Mojo::IOLoop->stop;
  }
);
Mojo::IOLoop->start;
Mojo::IOLoop->remove($id);
like $fail, qr/timeout|Premature/, 'right error';

done_testing();
