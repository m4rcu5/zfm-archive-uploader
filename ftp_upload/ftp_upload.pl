#!/usr/bin/perl
#
# This utility looks like a hardcoded mess, but
# does its job uploading our 24h recordings to
# archive.org by scanning for identifiers.
#
# Use PAR::Packer on a Strawberry Perl distibution
# to create a self contained binary, eg:
# pp -v -o ftp_upload.exe ftp_upload.pl
#
# Copyright (C) Marcus van Dam <marcus@zfmzandvoort.nl>
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
use strict;
use warnings;

use threads;
use Thread::Queue;

use File::Glob ':glob';
use File::Basename;
use File::Spec;
use Net::FTP;

# Config parameters.
my $params = {
	Debug => 1,

	Host  => "items-uploads.archive.org",
	User  => "user\@domain.tld",
	Pass  => "password",

	LogDir => "C:\\Data\\Log24",
	Log    => basename($0) . ".log",

	Threads => 8
};

# Start all connections
my @ftpconns = ftpconnect($params);

# Select first connection for parent
my $ftp = $ftpconns[0];

# Start our working queue
my $queue = Thread::Queue->new();

# Loop over Identifiers
foreach ($ftp->ls(".")) {
	my $dir = $_;

	$dir =~ m/ZFM-([0-9]{4})-([0-9]{2})-([0-9]{2})/x or next;

	# Derive dates from dirname
	my ($year, $month, $day) = ($1, $2, $3);

	logmsg("Scanning date: " . $dir);

	# Fetch file list from FTP
	my %list_remote = map {$_ => 1} $ftp->ls($dir);

	# Fetch files from local dir
	my @list_local = bsd_glob(
		File::Spec->catfile(
			$params->{LogDir}, "${year}-${month}-${day}_[0-9][0-9].MP3"
		)
	);
	@list_local = map { basename($_) } @list_local;

	logmsg("Files found: Remote " . scalar(keys %list_remote) . " Local " . scalar(@list_local));

	# Delete remote files from TODO list
	my @todo = grep { not $list_remote{$_} } @list_local;

	logmsg("Files queued: " . scalar(@todo));
	logmsg("::" . $_) foreach (@todo);

	# Add TODO list to queue
	$queue->enqueue([$_, $dir . "/" . $_]) foreach (@todo);
}

$queue->end();

logmsg("#################################");
logmsg("## Finished building queue");
logmsg("## Enqueued files: " . $queue->pending());
logmsg("## Selected threads: " . $params->{Threads});
logmsg("#################################");

# Launch threads to process our queue
my @threads = map async {
	while ( defined( $queue->peek ) ) {
		my ($lfile, $rfile) = @{$queue->dequeue};
		logmsg("Uploading file: " . $lfile);

		$ftpconns[threads->tid() - 1]->put(
			File::Spec->catfile($params->{LogDir}, $lfile), $rfile
		) or logmsg("[WARN] " . $lfile . " failed: " . $ftp->message);
	}
}, 1 .. $params->{Threads};

# Waiting to finish
$_->join() for @threads;

# close our FTP connections
$_->quit() for @ftpconns;

exit(0);

# Start connections for all threads
sub ftpconnect {
	my ($params) = @_;

	my @connections = map {
		# Connect to FTP server
		my $ftp = Net::FTP->new(
			$params->{Host},
			Debug   => $params->{Debug},
			Passive => 1
		) or do {logmsg("[FATAL] " . $@) && die};

		# Login to FTP server
		$ftp->login(
			$params->{User},
			$params->{Pass}
		) or do {logmsg("[FATAL] " . $ftp->message) && die};

		# Return the FTP object
		$ftp;
	} 1 .. $params->{Threads};

	return @connections;
}

# Logger subroutine
sub logmsg {
    my ( $msg, $stderr ) = @_;

    my ( $logsec, $logmin, $loghour, $logday, $logmon ) = (localtime(time))[0..4];
    my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my $timestamp = sprintf( "%3s %02d %02d:%02d:%02d", $abbr[$logmon], $logday, $loghour, $logmin, $logsec );

    $msg = "$timestamp: $msg \n";

    open(my $fh, '>>', $params->{Log}) or die "Unable to open logfile: $!";
    (print $fh $msg) && (warn $msg);
    close($fh);

    return;
}
