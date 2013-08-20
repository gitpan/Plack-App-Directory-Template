use Test::More;
use Plack::Test;
use HTTP::Request;

use Plack::App::Directory::Template;

my $app = Plack::App::Directory::Template->new(
    root => 't/dir'
);

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(HTTP::Request->new(GET => '/'));

    is $res->code, 200;
    ok $res->content =~ /class='size'>1</m;
    ok $res->content =~ qr{<a href='/%23foo'>\#foo</a>}m;
};

$app = Plack::App::Directory::Template->new(
    root => 't/dir',
    templates => \"[% files.size %]",
);

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(HTTP::Request->new(GET => '/'));

    is $res->content, 4, 'template as string reference';
};

done_testing;
