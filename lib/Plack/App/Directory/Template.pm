package Plack::App::Directory::Template;
{
  $Plack::App::Directory::Template::VERSION = '0.21';
}
#ABSTRACT: Serve static files from document root with directory index template

use strict;
use warnings;
use v5.10.1;

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
    my @special = ('.');
    push @special, '..' if $env->{PATH_INFO} !~ qr{^/?$};

    foreach ( @special, sort { $a cmp $b } @children ) {
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

    $env->{'tt.vars'} = $self->template_vars($dir, \@files);
    $env->{'tt.template'} = ref $self->{templates}
                          ? $self->{templates} : 'index.html';

    $self->{tt} //= Plack::Middleware::TemplateToolkit->new(
        INCLUDE_PATH => $self->{templates}
                        // eval { dist_dir('Plack-App-Directory-Template') }
                        // 'share',
        request_vars => [qw(scheme base parameters path user)],
    )->to_app;

    return $self->{tt}->($env);
}

sub template_vars {
    my ($self, $dir, $files) = @_;

    return {
        dir   => abs_path($dir),
        files => $self->filter ?
                 [ grep { defined $_ } map { $self->filter->($_) } @$files ]  : $files,
    };
}


1;

__END__

=pod

=head1 NAME

Plack::App::Directory::Template - Serve static files from document root with directory index template

=head1 VERSION

version 0.21

=head1 SYNOPSIS

    use Plack::App::Directory::Template;

    my $template = "/path/to/templates"; # or \$template_string

    my $app = Plack::App::Directory::Template->new(
        root      => "/path/to/htdocs",
        templates => $template, # optional
        filter    => sub {
             # hide hidden files
             $_[0]->{name} =~ qr{^[^.]|^\.+/$} ? $_[0] : undef;
        }
    )->to_app;

=head1 DESCRIPTION

This does what L<Plack::App::Directory> does but with more fancy looking
directory index pages. The template is passed to the following variables:

=over 4

=item dir

The directory that is listed (absolute server path).

=item files

List of files, each with the following properties. All directory names end with
a slash (C</>). The special directory C<./> is included and C<../> as well, 
unless the root directory is listed.

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

Most part of the code is copied from L<Plack::App::Directory>.

=head1 CONFIGURATION

=over 4

=item root

Document root directory. Defaults to the current directory.

=item templates

Template directory that must include at least a file named C<index.html> or
template given as string reference.

=item filter

A code reference that is called for each file before files are passed as
template variables  One can use such filter to omit selected files and to
modify or extend file objects.

=back

=head1 METHODS

=head2 template_vars($dir, \@files)

This method is internally used to construct a hash reference with template
variables (C<dir> and C<files>) from the directory and an unfiltered list of
files. It is documented here as possible hook for subclasses that add more
template variables.

=head1 SEE ALSO

L<Plack::App::Directory>, L<Plack::Middleware::TemplateToolkit>

=encoding utf8

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
