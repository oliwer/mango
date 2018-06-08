
package Mango::Promises;

use Mojo::Base -strict;

use Carp       ();
use Mojo::Util ();

use constant PROMISES => !!eval { require Mojo::Promise; 1 };

sub generate_p_methods {
  my ($class, $package) = (shift, scalar caller);
  my %patch;
  for (@_) {
    my ($meth, $arity) = split '/';
    my $args = ($arity // 1) eq '0' ? '' : '$_[2]';
    my $code = q[
      sub {
        Carp::croak "METHOD\_p() requires Mojo::Promise" unless PROMISES;
        my $self    = shift;
        my $promise = Mojo::Promise->new;
        $self->METHOD(
          @_ => sub {
            $_[1] ? $promise->reject($_[1]) : $promise->resolve(ARGS);
          }
        );
        return $promise;
      }
    ];
    s/\bMETHOD\b/$meth/g, s/\bARGS\b/$args/g for $code;
    $patch{"${meth}_p"} = eval $code;
  }
  Mojo::Util::monkey_patch $package, %patch;
}

1;

=encoding utf8

=head1 NAME

Mango::Promises - Mango with promises

=head1 SYNOPSIS

    use Mango;
    use feature 'state';

    # Declare a Mango helper
    sub mango { state $m = Mango->new('mongodb://localhost:27017') }

    # Non-blocking concurrent find
    my @u = map {
      mango->db('test')->collection('users')->find_one_p({username => $_})
    } qw(sri marty);
    Mojo::Promise->all(@u)->then(
      sub {
        say $_->[0]{display_name} for @_;
      }
    );

=head1 DESCRIPTION

Since version 1.31, L<Mango> supports non-blocking with promise-returning
methods. The public interface for this capability are the C<_p> methods
at L<Mango> and related classes.

L<Mango::Promises> is an internal class that helps to generate and install
promisified versions of methods into L<Mango> and related classes.
No user-serviceable parts inside.

Note that promise support depends on L<Mojo::Promise> (L<Mojolicious> 7.53+).
If L<Mojo::Promise> can't be loaded, every C<_p> method will croak
with a message such as

    insert_p() requires Mojo::Promise

=begin :private

=head1 METHODS

=head2 generate_p_methods

    Mango::Promises->generate_p_methods(@methods);

This method, I<which is likely to change or go away>, installs into
the caller package promisified versions of the given methods.

=end :private

=head1 SEE ALSO

L<Mango>, L<Mojo::Promise>.

=cut
