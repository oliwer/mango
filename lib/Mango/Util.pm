package Mango::Util;

use strict;
use warnings;
use Exporter 'import';
use Carp;

our @EXPORT_OK = qw(in_global_destruction refcount);

# Perl's global destruction phase detection
{
  if (defined ${^GLOBAL_PHASE}) {
    # we run perl 5.14+
    eval 'sub in_global_destruction () { ${^GLOBAL_PHASE} eq q[DESTRUCT] }; 1'
      or die $@;
  }
  else {
    require B;
    eval 'sub in_global_destruction () { ${B::main_cv()} == 0 }; 1'
      or die $@;
  }
}

sub refcount {
  # We cannot use a local variable here or
  # it would increment the refcount
  croak "Expecting a reference" unless ref $_[0];

  require B;
  B::svref_2object($_[0])->REFCNT;
}

1;

=encoding utf8

=head1 NAME

Mango::Util - xxx

=head1 DESCRIPTION

This module is for internal use only. You most certainly do not need
any of this.

Most of the code here was taken from L<DBIx::Class::_Util>. Kudos to them.

=head1 FUNCTIONS

=head2 in_global_destruction

  my $bool = in_global_destruction;

Return if the the program is curently in the 'DESTRUCT' phase or not.

=head2 refcount

  my $number = refcount($reference);

Return the value of the reference counter of the given reference. Will croak
if not given a valid reference.

=head1 SEE ALSO

L<Mango>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
