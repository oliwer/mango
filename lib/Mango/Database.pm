package Mango::Database;
use Mojo::Base -base;

use Carp 'croak';
use Mango::BSON qw(bson_code bson_doc);
use Mango::Collection;
use Mango::GridFS;
use Mango::Promises;

has [qw(mango name)];

Mango::Promises->generate_p_methods(
  qw(collection_names command dereference list_collections stats));

sub build_write_concern {
  my $mango = shift->mango;
  return {
    j => $mango->j ? \1 : \0,
    w => $mango->w,
    wtimeout => $mango->wtimeout
  };
}

sub collection {
  my ($self, $name) = @_;
  return Mango::Collection->new(db => $self, name => $name);
}

sub collection_names {
  my $self = shift;
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;

  # Non-blocking
  return $self->list_collections(@_ => sub {
    my ($self, $err, $cursor) = @_;
    return $self->$cb($err, []) if $err;
    $cursor->all(sub {
      my ($cursor, $err, $docs) = @_;
      @$docs = map { $_->{name} } @$docs;
      $self->$cb($err, $docs);
    });
  }) if $cb;

  # Blocking
  my $docs = $self->list_collections(@_)->all;
  @$docs = map { $_->{name} } @$docs;
  return $docs;
}

sub command {
  my ($self, $command) = (shift, shift);
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  $command = ref $command ? $command : bson_doc($command => 1, @_);

  # Non-blocking
  my $mango    = $self->mango;
  my $name     = $self->name;
  my $protocol = $mango->protocol;
  return $mango->query(
    ("$name.\$cmd", {}, 0, -1, $command, {}) => sub {
      my ($collection, $err, $reply) = @_;
      my $doc = $reply->{docs}[0];
      $err ||= $protocol->command_error($doc);
      $self->$cb($err, $doc);
    }
  ) if $cb;

  # Blocking
  my $doc = $mango->query("$name.\$cmd", {}, 0, -1, $command, {})->{docs}[0];
  if (my $err = $protocol->command_error($doc)) { croak $err }
  return $doc;
}

sub dereference {
  my ($self, $dbref, $cb) = @_;

  # Non-blocking
  my $collection = $self->collection($dbref->{'$ref'});
  return $collection->find_one($dbref->{'$id'} => sub { shift; $self->$cb(@_) }
  ) if $cb;

  # Blocking
  return $collection->find_one($dbref->{'$id'});
}

sub gridfs { Mango::GridFS->new(db => shift) }

sub list_collections {
  my $self = shift;
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;

  my $command = bson_doc(listCollections => 1, @_);

  # Non-blocking
  return $self->command($command => sub {
    my ($self, $err, $res) = @_;
    $res = $res->{cursor};
    my $cursor = Mango::Cursor->new(collection => $self->collection,
      id => $res->{id}, ns => $res->{ns})->add_batch($res->{firstBatch});
    $self->$cb($err, $cursor);
  }) if $cb;

  # Blocking
  my $cursor = $self->command($command)->{cursor};
  return Mango::Cursor->new(collection => $self->collection,
    id => $cursor->{id}, ns => $cursor->{ns})
    ->add_batch($cursor->{firstBatch});
}

sub stats { shift->command(bson_doc(dbstats => 1), @_) }

1;

=encoding utf8

=head1 NAME

Mango::Database - MongoDB database

=head1 SYNOPSIS

  use Mango::Database;

  my $db = Mango::Database->new(mango => $mango);
  my $collection = $db->collection('foo');
  my $gridfs     = $db->gridfs;

=head1 DESCRIPTION

L<Mango::Database> is a container for MongoDB databases used by L<Mango>.

=head1 ATTRIBUTES

L<Mango::Database> implements the following attributes.

=head2 mango

  my $mango = $db->mango;
  $db       = $db->mango(Mango->new);

L<Mango> object this database belongs to. Note that this reference is usually
weakened, so the L<Mango> object needs to be referenced elsewhere as well.

=head2 name

  my $name = $db->name;
  $db      = $db->name('bar');

Name of this database.

=head1 METHODS

L<Mango::Database> inherits all methods from L<Mojo::Base> and implements the
following new ones.

=head2 build_write_concern

  my $concern = $db->build_write_concern;

Build write concern based on l</"mango"> settings.

=head2 collection

  my $collection = $db->collection('foo');

Build L<Mango::Collection> object for collection.

=head2 collection_names

  my $names = $db->collection_names;

Names of all collections in this database. You can filter the results by using
the same arguments as for C<list_collections>. You can also append a callback
to perform operation non-blocking.

  $db->collection_names(sub {
    my ($db, $err, $names) = @_;
    ...
  });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

=head2 collection_names_p

  my $promise = $db->collection_names_p;

Same as L</"collection_names">, but performs a non-blocking operation
and returns a L<Mojo::Promise> object instead of accepting a callback.

Notice that promise support depends on L<Mojo::Promise> (L<Mojolicious> 7.53+).

=head2 command

  my $doc = $db->command(bson_doc(text => 'foo.bar', search => 'test'));
  my $doc = $db->command(bson_doc(getLastError => 1, w => 2));
  my $doc = $db->command('getLastError', w => 2);

Run command against database. You can also append a callback to run command
non-blocking.

  $db->command(('getLastError', w => 2) => sub {
    my ($db, $err, $doc) = @_;
    ...
  });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

=head2 command_p

  my $promise = $db->command_p(bson_doc(text => 'foo.bar', search => 'test'));
  my $promise = $db->command_p(bson_doc(getLastError => 1, w => 2));
  my $promise = $db->command_p('getLastError', w => 2);

Same as L</"command">, but performs a non-blocking operation
and returns a L<Mojo::Promise> object instead of accepting a callback.

Notice that promise support depends on L<Mojo::Promise> (L<Mojolicious> 7.53+).

=head2 dereference

  my $doc = $db->dereference($dbref);

Resolve database reference. You can also append a callback to perform
operation non-blocking.

  $db->dereference($dbref => sub {
    my ($db, $err, $doc) = @_;
    ...
  });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

=head2 dereference_p

  my $promise = $db->dereference_p($dbref);

Same as L</"dereference">, but performs a non-blocking operation
and returns a L<Mojo::Promise> object instead of accepting a callback.

Notice that promise support depends on L<Mojo::Promise> (L<Mojolicious> 7.53+).

=head2 gridfs

  my $gridfs = $db->gridfs;

Build L<Mango::GridFS> object.

=head2 list_collections

  # return a cursor for all collections
  my $cursor = $db->list_collections;
  # only collections which name matchs a regex
  my $cursor = $db->list_collections(filter => { name => qr{^prefix} });
  # only capped collections
  my $cursor = $db->list_collections(filter => { 'options.capped' => 1 });
  # only the first 10 collections
  my $cursor = $db->list_collections(cursor => { batchSize => 10 });

Returns a L<Mango::Cursor> of all collections in this database. Each collection
is represented by a document containing at least the keys C<name> and
C<options>. You can also append a callback to perform operation non-blocking.

  $db->list_collections(sub {
    my ($db, $err, $cursor) = @_;
    ...
  });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

=head2 list_collections_p

  my $promise = $db->list_collections_p;
  my $promise = $db->list_collections_p(filter => { name => qr{^prefix} });
  my $promise = $db->list_collections_p(filter => { 'options.capped' => 1 });
  my $promise = $db->list_collections_p(cursor => { batchSize => 10 });

Same as L</"list_collections">, but performs a non-blocking operation
and returns a L<Mojo::Promise> object instead of accepting a callback.

Notice that promise support depends on L<Mojo::Promise> (L<Mojolicious> 7.53+).

=head2 stats

  my $stats = $db->stats;

Get database statistics. You can also append a callback to perform operation
non-blocking.

  $db->stats(sub {
    my ($db, $err, $stats) = @_;
    ...
  });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

=head2 stats_p

  my $promise = $db->stats_p;

Same as L</"stats">, but performs a non-blocking operation
and returns a L<Mojo::Promise> object instead of accepting a callback.

Notice that promise support depends on L<Mojo::Promise> (L<Mojolicious> 7.53+).

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
