#!/usr/bin/perl

# This program generates a Window Maker submenu from a folder in Firefox
# bookmarks.  It retrieves the bookmarks via sqlite3, traverses them to create a
# Perl representation and, finally, converts the Perl representation to a Window
# Maker-compatible format.  For this, it relies on the `pp` subroutine from
# Data::Dump.

# Note that the program might jumble up titles and addresses that contain
# /,\s+\)/ :-)

use v5.24;
use strict;
use warnings;

use DBI;
use Data::Dump qw/pp/;
use subs qw/traverse/;

# Configuration:
my $profile_path = '/home/john/.mozilla/firefox/xejb61u6.default';
my $folder_title = 'Window Maker';
my $command = 'firefox --new-tab';

my ($dbh, $id, $rows);

$dbh = DBI->connect("DBI:SQLite:dbname=$profile_path/places.sqlite")
    or die $DBI::errstr;

{ # Fetch folder id
    my $sth = $dbh->prepare('select id from moz_bookmarks where title = ?');
    $sth->execute($folder_title);
    $id = $sth->fetchrow_array;
}
{ # Fetch children
    my $sth = $dbh->prepare('select * from moz_bookmarks where parent = ?');
    $sth->execute($id);
    $rows = $sth->fetchall_arrayref({});
}

my @perl = ('Bookmarks');   # Create Perl representation
push @perl, traverse $rows;

my $wmaker = pp(@perl);     # Convert to Window Maker format
$wmaker =~ s/\[/\(/g;
$wmaker =~ s/\]/\)/g;
$wmaker =~ s/,(\s+)\)/$1\)/g;

print $wmaker, "\n";

# ------------------------------------------------------------------------------

sub traverse { # -- create Perl representation from database results
    my $rows = shift;
    my @list = ();
    for my $row (@{$rows}) {
        if ($row->{type} == 2) { # folder
            my $sth = $dbh->prepare('select * from moz_bookmarks where parent = ?');
            $sth->execute($row->{id});
            push @list, [
                $row->{title},
                traverse $sth->fetchall_arrayref({})
            ];
        } else { # bookmark
            my $sth = $dbh->prepare('select url from moz_places where id = ?');
            $sth->execute($row->{fk});
            my ($url) = $sth->fetchrow_array;
            push @list, [$row->{title}, 'EXEC', "$command '$url'"];
        }
    }
    return @list;
}
