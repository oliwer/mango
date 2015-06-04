package main;
use Mojo::Base -strict;

use Test::More;
use Mango;

my (@DESTROYED, @CREATED);
my $destroy = sub { push @DESTROYED, ref shift };
my $new     = sub { push @CREATED,   shift };

{
  package Mango::Auth::SCRAM;
  sub DESTROY { $destroy->(@_) }
  sub new { $new->(@_); shift->SUPER::new(@_) }

  package Mango::Auth::MyTest;
  use Mojo::Base 'Mango::Auth';
  sub new { $new->(@_); shift->SUPER::new(@_) }
  sub DESTROY { $destroy->(@_) }

  package Mango::My;
  use Mojo::Base 'Mango';
  sub new     { $new->(@_);     shift->SUPER::new(@_) }
  sub DESTROY { $destroy->(@_); shift->SUPER::DESTROY }
}

DEFAULT: {
  my $mango = Mango::My->new('mongodb://usr:pwd@127.0.0.1/db');
  is $mango->_auth->mango, $mango;
}

CUSTOM: {
  my $auth  = Mango::Auth::MyTest->new;
  my $mango = Mango::My->new->_auth($auth);
  is $mango->_auth->mango, $mango;
}

is @CREATED, 4;
is_deeply [sort @DESTROYED], [sort @CREATED];


done_testing;
