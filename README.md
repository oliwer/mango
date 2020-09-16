
  Pure-Perl non-blocking I/O MongoDB driver, optimized for use with the
  [Mojolicious](http://mojolicio.us) real-time web framework.
  It also supports [BSON::XS](https://metacpan.org/pod/BSON::XS) parser

```perl
use Mojolicious::Lite;
use Mango;
use BSON:Types ':all';

my $uri = 'mongodb://<user>:<pass>@<server>/<database>';
helper mango => sub { state $mango = Mango->new($uri) };

# Store and retrieve information non-blocking
get '/' => sub {
  my $c = shift;

  my $collection = $c->mango->db->collection('visitors');
  my $ip         = $c->tx->remote_address;

  # Store information about current visitor
  $collection->insert_p({when => bson_time, from => $ip})->then(sub {
    my ($oid) = @_;
    # Retrieve information about previous visitors
    $collection->find->sort({when => -1})->fields({_id => 0})->all_p->then(sub {
      my ($docs) = @_;
      # And show it to current visitor
      $c->render(json => $docs);
    })
  })->catch(sub {
    return $c->reply->exception(@_)
  })
};

app->start;
```

## Installation

  All you need is a oneliner, it takes less than a minute.

    $ curl -L cpanmin.us | perl - -n Mango

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.
