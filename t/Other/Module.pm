package Other::Module;

use Mango;

my $mango = Mango->new($ENV{TEST_ONLINE});
my $db = $mango->db('test');

sub list_collections {
	return $db->collection_names;
}

1;
