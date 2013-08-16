package Plack::App::Directory::Template;
#ABSTRACT: Serve static files from document root with directory index template

use strict;
use warnings;

use parent qw(Plack::App::Directory);

use Plack::Util::Accessor qw(filter);

use Plack::Middleware::TemplateToolkit;
use File::ShareDir qw(dist_dir);
use File::stat;
use DirHandle;
use Cwd qw(abs_path);
use URI::Escape;

sub serve_path {
    my($self, $env, $dir, $fullpath) = @_;
    
    if (-f $dir) {
        return $self->SUPER::serve_path($env, $dir, $fullpath);
    }

    my $dir_url = $env->{SCRIPT_NAME} . $env->{PATH_INFO};

    if ($dir_url !~ m{/$}) {
        return $self->return_dir_redirect($env);
    }

    my $dh = DirHandle->new($dir);
    my @children;
    while (defined(my $ent = $dh->read)) {
        next if $ent eq '.' or $ent eq '..';
        push @children, $ent;
    }

    my @files;

    foreach ( '.', '..', sort { $a cmp $b } @children ) {
        my $name = $_;
        my $file = "$dir/$_";
        my $url  = $dir_url . $_;
        my $stat = stat($file);
        
        $url = join '/', map {uri_escape($_)} split m{/}, $url;

        my $is_dir = -d $file; # TODO: use Fcntl instead

        push @files, { 
            name        => $is_dir ? "$name/" : $name,
            url         => $is_dir ? "$url/" : $url,
            mime_type   => $is_dir ? 'directory' : ( Plack::MIME->mime_type($file) || 'text/plain' ),
            ## no critic
            permission  => $stat ? ($stat->mode & 07777) : undef,
            stat        => $stat,
        }
    } 

    my $vars = {
        files => \@files,
        dir   => abs_path($dir),
    };
    $self->filter->($vars) if $self->filter;

    $self->{tt} //= Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $self->{templates} 
                        // eval { dist_dir('Plack-App-Directory-Template') } 
                        // 'share',
        request_vars => [qw(scheme base parameters path user)],
    )->to_app;

    $env->{'tt.vars'}     = $vars;
    $env->{'tt.template'} = 'index.html';

    return $self->{tt}->($env);
}

=head1 SYNOPSIS

    use Plack::App::Directory;
    my $app = Plack::App::Directory->new({ 
        root      => "/path/to/htdocs",
        templates => "/path/to/templates",  # optional
        filter    => sub {
            $_[0]->{files} = [              # hide hidden files
                 grep { $_->{name} =~ qr{^[^.]|^\.+/$} } @{$_[0]->{files}}
            ];
        }
    })->to_app;

=head1 DESCRIPTION

This does what L<Plack::App::Directory> does but with more fancy looking
directory index pages. The template is passed to the following variables:

=over 4

=item dir

The directory that is listed (absolute server path).

=item files

List of files, each with the following properties. The special files C<.> and
C<..> are included on purpose. All directory names end with a slash (C</>).

=over 4

=item file.name

Local file name (basename).

=item file.url

URL path of the file.

=item file.mime_type

MIME type of the file.

=item file.stat

File status info as given by L<File::Stat> (dev, ino, mode, nlink, uid, gid,
rdev, size, atime, mtime, ctime, blksize, and block).

=item file.permission

File permissions (given by C<< file.stat.mode & 0777 >>). For instance one can
print this in a template with C<< [% file.permission | format("%04o") %] >>.

=item

=back

=item request

Information about the HTTP request as given by L<Plack::Request>. Includes the
properties L<parameters>, L<base>, L<scheme>, L<path>, and L<user>.

=back

Most part of the code is copied from Plack::App::Directory.

=head1 CONFIGURATION

=over 4

=item root

Document root directory. Defaults to the current directory.

=item templates

Template directory that must include at least a file named C<index.html>.

=item filter

A code reference that is passed a hash reference with the template variables
C<dir> and C<files>. The reference can be modified before it is passed to the
template, for instance to filter and extend file information.

=back

=head1 SEE ALSO

L<Plack::App::Directory>, L<Plack::Middleware::TemplateToolkit>

=cut

1;
