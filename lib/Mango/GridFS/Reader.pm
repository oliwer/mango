package Mango::GridFS::Reader;
use Mojo::Base -base;

has 'gridfs';

sub chunk_size { shift->{meta}{chunkSize} }
sub filename   { shift->{meta}{filename} }

sub open {
  my ($self, $oid) = @_;
  $self->{meta} = $self->gridfs->files->find_one($oid);
}

sub read {
  my $self = shift;

  $self->{pos} //= 0;
  return undef if $self->{pos} >= $self->size;
  my $n     = $self->{pos} / $self->chunk_size;
  my $chunk = $self->gridfs->chunks->find_one(
    {files_id => $self->{meta}{_id}, n => $n});
  my $data = $chunk->{data};
  $self->{pos} += length $data;
  return $data;
}

sub size        { shift->{meta}{length} }
sub upload_date { shift->{meta}{uploadDate} }

1;

=encoding utf8

=head1 NAME

Mango::GridFS::Reader - GridFS reader

=head1 SYNOPSIS

  use Mango::GridFS::Reader;

  my $reader = Mango::GridFS::Reader->new(gridfs => $gridfs);

=head1 DESCRIPTION

L<Mango::GridFS::Reader> reads files from GridFS.

=head1 ATTRIBUTES

L<Mango::GridFS::Reader> implements the following attributes.

=head2 gridfs

  my $gridfs = $reader->gridfs;
  $reader    = $reader->gridfs(Mango::GridFS->new);

L<Mango::GridFS> object this reader belongs to.

=head1 METHODS

L<Mango::GridFS::Reader> inherits all methods from L<Mojo::Base> and
implements the following new ones.

=head2 chunk_size

  my $size = $reader->chunk_size;

Chunk size in bytes.

=head2 filename

  my $name = $reader->filename;

Name of file.

=head2 open

  $reader->open(bson_oid '1a2b3c4e5f60718293a4b5c6');

Open file.

=head2 read

  my $chunk = $reader->read;

Read chunk.

=head2 size

  my $size = $reader->size;

Size of entire file in bytes.

=head2 upload_date

  my $time = $reader->upload_date;

Date file was uploaded.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
