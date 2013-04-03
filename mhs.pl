#!/usr/bin/perl -w
use Proc::Daemon;
use Sys::Hostname;
use Net::Server::NonBlocking;
use DBI;
Proc::Daemon::Init;
$SIG{PIPE}='IGNORE';
$|=1;

$server=Net::Server::NonBlocking->new();


$server->add({
		server_name => 'mysql health server',
		local_port => 10001,
		timeout => 60,
		delimeter => "\n",
		on_connected => \&mhs_connected,
		on_disconnected => \&mhs_disconnected,
		on_recv_msg	=> \&mhs_disconnected
	}) or die "Can't start server\n";

sub mhs_connected {
	my $self=shift;
	my $client=shift;
	my $dbstatus=0;

	print "Client connected...\n";
	$dbstatus += &check_database_alive;
	$dbstatus += &check_backup_in_progress;
	$dbstatus += &check_replication;
	
	if ($dbstatus >= 1) {
		print $client "1\n";
	}else{
		print $client "0\n";
	}
	$self->erase_client('mysql health server',$client);
}

sub mhs_disconnected {
	my $self=shift;
	my $client=shift;
	
	print "Client disconnected\n";
}

sub check_backup_in_progress {
	my $hostname = hostname;
	my $dsn = "DBI:mysql:database=sysops;host=$hostname;port=3306";
	my $dbh = DBI->connect($dsn, 'username', 'password');

	my $sth = $dbh->prepare("SELECT locked from job_locks where name = 'backup'");
	$sth->execute();
	my ($bustatus) = $sth->fetchrow_array();
	print "Backup status is: $bustatus\n";
	return $bustatus;
}

sub check_database_alive {
	my $hostname = hostname;
	my $dsn = "DBI:mysql:database=sysops;host=$hostname;port=3306";
	my $dbh = DBI->connect($dsn, 'username', 'password') or die return 1;
	
	my $sth = $dbh->prepare("SELECT 0") or die return 1;
	$sth->execute() or die return 1;
	print "Database connection is valid\n";
	my ($status) = $sth->fetchrow_array();
	return $status;
}

sub check_replication {
	my $hostname = hostname;
	my $dsn = "DBI:mysql:database=sysops;host=$hostname;port=3306";
	my $dbh = DBI->connect($dsn, 'username', 'password') or die return 1;

	my $sth = $dbh->prepare("SHOW SLAVE STATUS") or die return 1;
	$sth->execute() or die return 1;

	while (my $rows = $sth->fetchrow_hashref()) {
		$slaveiorun = $rows->{Slave_IO_Running};
		$slavesqlrun = $rows->{Slave_SQL_Running};
		$mlf = $rows->{Master_Log_File};
		$rmlf = $rows->{Relay_Master_Log_File};
		$sbm = $rows->{Seconds_Behind_Master};

	}
	my $status = 0;
	if ($slaveiorun ne "Yes") {
		print "Slave_IO_Run: $slaveiorun\n";
		return 1;
	}

	if ($slavesqlrun ne "Yes") {
		print "Slave_SQL_Run: $slavesqlrun\n";
		return 1;
	}

	if ($mlf ne $rmlf) {
		print "Master Log File: $mlf\n";
		print "Relay Master Log file: $rmlf\n";
		return 1;
	}

	if ($sbm eq '') {
		print "Seconds Behind Master is NULL\n";
		return 1;
	}

        if ($sbm >= 60) {
                print "Seconds Behind Master: $sbm\n";
                return 1;
        }
	return $status;

}
$> = getpwnam('scripts');
$) = getgrnam('scripting');
$server->start;
