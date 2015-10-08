package main;
use Mojo::Base -strict;

use Test::More;
use Mango;
use Data::Dumper;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

{
  package Mango::Auth::MyTest;
  use Mojo::Base 'Mango::Auth';
}

my $mango = Mango->new();
is $mango->_auth, undef, 'no auth';

$mango = Mango->new('mongodb://127.0.0.1');
is $mango->_auth, undef, 'no auth';

$mango = Mango->new('mongodb://127.0.0.1/mydb');
is $mango->_auth, undef, 'no auth';

my $auth = Mango::Auth::MyTest->new;
is $mango->_auth($auth), $mango, 'returns self';
is $auth->mango, $mango, 'mango was installed';

# defaults
$mango = Mango->new('mongodb://usr:pwd@127.0.0.1/db');
isa_ok $mango->_auth, 'Mango::Auth::SCRAM';

# ioc
$mango = Mango->new('mongodb://SECRET:SECRET@127.0.0.1/db');
like Dumper($mango), qr /^((?!SECRET).)*$/s;

done_testing;
