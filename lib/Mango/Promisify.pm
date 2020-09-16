package Mango::Promisify;
use Mojo::Base -strict;

use Exporter 'import';

use Mojo::Util qw(monkey_patch);
use Mojo::Promise;

our @EXPORT = qw( promisify );

sub promisify {
    my ($name) = @_;
    my $name_p = $name . '_p';
    my ($package) = caller(0);
    no strict 'refs';
    my $method = \&{"${package}::$name"};
    monkey_patch $package, $name_p => sub {
        my (@args) = @_;
        my $promise = Mojo::Promise->new;
        $method->(@args, sub {
            my ($self, $err, $result) = @_;
            return $promise->reject($err) if $err;
            $promise->resolve($result)
        });
        return $promise
    } 
}

1;