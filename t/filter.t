use Test::More;
use Plack::Test;
use HTTP::Request;

use Plack::App::Directory::Template;

my $app = Plack::App::Directory::Template->new(
    root      => 't/dir',
    templates => 't/templates',
    filter    => sub {
        $_[0]->{files} = [
             grep { $_->{name} =~ qr{^[^.]|^\.+/$} } @{$_[0]->{files}}
        ];
    }
);

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(HTTP::Request->new(GET => '/subdir/'));

    is $res->code, 200, 'ok';
    is $res->content, "./\n../\nfoo.txt\n", 'filter';
};
    
done_testing;
