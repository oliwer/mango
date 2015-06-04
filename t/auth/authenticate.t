package main;
use Mojo::Base -strict;

use Test::More;
use Mango;
use Data::Dumper;

my (@ARGS, $called, $mango);

{
  package Mango::Auth::Test;
  use Mojo::Base 'Mango::Auth';
  sub _authenticate { @ARGS = @_; $called++; }
}

# blocking
(@ARGS, $called) = ();
$mango = Mango->new('mongodb://user:pass@127.0.0.1/test')
  ->_auth(Mango::Auth::Test->new());

eval { $mango->db->stats() };

is $called, 1, 'was called';
ok !$mango->{connections}{$ARGS[1]}->{nb}, 'blocking';

# nb
(@ARGS, $called) = ();
$mango->db->stats(sub { Mojo::IOLoop->stop });
eval { Mojo::IOLoop->start };

is $called, 1, 'was called';
ok $mango->{connections}{$ARGS[1]}->{nb}, 'not blocking';

done_testing;
