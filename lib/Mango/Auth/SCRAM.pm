package Mango::Auth::SCRAM;

use Mojo::Base 'Mango::Auth';
use Mojo::Util qw(dumper md5_sum encode b64_encode b64_decode);
use Mango::BSON 'bson_doc';

EVAL: {
  local $@;
  die "Authen::SCRAM is required to use SCRAM-SHA-1\n"
    unless eval { require Authen::SCRAM::Client; 1 };
}

sub _credentials {
  my ($self, $creds) = @_;

  # [db, user, pass]
  $creds->[2]
    = md5_sum(encode("UTF-8", $creds->[1] . ":mongo:" . $creds->[2]));
  $self->{credentials} = $creds;
}

sub _authenticate {
    my ($self, $id) = @_;

    my $mango = $self->mango;
    my $cnx   = $self->mango->{connections}{$id};
    my $creds = $self->{credentials};

    my ($db, $user, $pass) = @$creds;

    my $scram_client = Authen::SCRAM::Client->new(
        skip_saslprep => 1,
        username      => $user,
        password      => $pass
    );

    my $loop = Mojo::IOLoop->new;
    my $conv_id;

    my $command = $self->_cmd_sasl_start($scram_client->first_msg);
    $mango->_fast($id, $db, $command, sub {
        my ($mango, $err, $doc) = @_;
        $conv_id = $doc->{conversationId};
        my $final_msg = $scram_client->final_msg(b64_decode $doc->{payload});

        my $command = $self->_cmd_sasl_continue($conv_id, $final_msg);
        $mango->_fast($id, $db, $command, sub {
            my ($mango, $err, $doc) = @_;
            $scram_client->validate(b64_decode $doc->{payload});

            my $command = $self->_cmd_sasl_continue($conv_id, '');
            $mango->_fast($id, $db, $command, sub {
                my ($mango, $err, $doc) = @_;
                $mango->emit(connection => $id)->_next;
                $loop->stop;
            })
        })
    });

    $loop->start;
}

sub _cmd_sasl_start {
  my ($self, $first_msg) = @_;

  bson_doc(
    'saslStart'     => 1,
    'mechanism'     => 'SCRAM-SHA-1',
    'payload'       => b64_encode($first_msg, ''),
    'autoAuthorize' => 1,
  );
}

sub _cmd_sasl_continue {
  my ($self, $conv_id, $final_msg) = @_;

  bson_doc(
    'saslContinue'   => 1,
    'conversationId' => $conv_id,
    'payload'        => $final_msg ? b64_encode($final_msg, '') : ''
  );
}

1;

=encoding utf8

=head1 NAME

Mango::Auth::SCRAM - SCRAM-SHA-1 Authentication

=head1 DESCRIPTION

The default authentication backend for L<Mango> using the SCRAM-SHA-1 algorithm.
It requires L<Authen::SCRAM>.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
