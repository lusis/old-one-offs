#!/usr/bin/perl -w
use strict;

use Getopt::Std;
use DBI;
use Cache::SharedMemoryCache;
use Getopt::Long;


use lib "third-party/";

use utils qw(%ERRORS);

use vars qw/ %opt /;

# globals
my $o_help		=	undef; # Help
my $o_hostname 		= 	undef; # Hostname
my $o_username 		= 	undef; # Username
my $o_password 		= 	undef; # Password
my $o_bufferpool 	= 	undef; # Bufferpool Check
my $o_qps 		=	undef; # Queries per second Check
my $o_pagecache		= 	undef; # Page cache Check
my $o_threadcache	= 	undef; # Thread Cache Check
my $o_querycache	= 	undef; # Query Cache Check
my $o_connections	=	undef; # Percent connections in use
my $o_warn		=	undef; # Warning value 
my $o_crit		=	undef; # Critical value
my $results		=	undef; # Results
my $n_status		=	undef; # Status
my $n_perfdata		=	undef; # Performance data
my $n_output		=	undef; # Output
my $cache		=	undef; # Cache object

sub connect {
	my($dbh) = DBI->connect ("DBI:mysql:host=$o_hostname",$o_username,$o_password)
		or die "Can't connect to database\n";
	return $dbh;
	}

sub check_cache {
	my($getvars) = "SHOW GLOBAL VARIABLES";
	my($testcache) = $cache->get ( 'version' );
	if($testcache){
		return 1;
	}else{
		my($dbh) = &connect;
		my($sth) = $dbh->prepare('SHOW GLOBAL VARIABLES');
		$sth->execute;
		while(my(@settings) = $sth->fetchrow_array())
		{
			$cache->set ( $settings[0], $settings[1], "10 minutes" )
				or die "Cannot populate cache";
		}
		return 1;
	}
}

sub get_cached_value {
	my($param)=shift;
	if( &check_cache ) {
		my($cachedval)= $cache->get($param);
		return $cachedval;
	}else{
		die "Could not get value from cache\n";
	}
}

sub get_live_value {
	my($param)=shift;
	my($dbh) = &connect;
        # Change to SHOW /*!50002 GLOBAL */ STATUSper comment on nagiosexchange
	my($sth) = $dbh->prepare("SHOW /*!50002 GLOBAL */ STATUS  LIKE '$param'");
	$sth->execute;
	my(@livevals) = $sth->fetchrow_array()
		or die "Cannot get value from database";
	return $livevals[1];
}

sub connection_use {
	my($max_connections)=&get_cached_value('max_connections');
	my($current_connections)=&get_live_value('threads_connected');
	my($percent_used) = ($current_connections/$max_connections)*100;
	return sprintf("%.2f", $percent_used);
}

sub qcache_hit_ratio {
	my($qcache_hits)=&get_live_value('qcache_hits');
	#my($com_select)=&get_live_value('com_select');
	my($qcache_inserts)=&get_live_value('qcache_inserts');
	my($qcache_not_cached)=&get_live_value('qcache_not_cached');
	# Original query I created
	#my($hit_ratio)=($qcache_hits/($qcache_hits + $com_select))*100;
	# Innotop logic
	#my($hit_ratio)=(( $qcache_hits||0 )/( ( ($com_select||0) + ($qcache_hits||0) )||1) ) * 100;
	# http://www.pythian.com/blogs/437/mysql-memory-usage-profile-script-2 logic
	# This was the only one I could get to match the same results I was seeing in innotop so I'm using it.
	my($hit_ratio) = ($qcache_hits / ($qcache_hits + $qcache_inserts + $qcache_not_cached)) * 100;
	return sprintf("%.2f", $hit_ratio);
}

sub tcache_hit_ratio {
	my($threads_created)=&get_live_value('threads_created');
	my($connections)=&get_live_value('connections');
	my($hit_ratio)=100 - (($threads_created / $connections) * 100);
	return sprintf("%.2f", $hit_ratio);
}

sub innodb_page_cache_usage {
	my($innodb_buffer_pool_pages_free)=&get_live_value('innodb_buffer_pool_pages_free');
	my($innodb_buffer_pool_pages_total)=&get_live_value('Innodb_buffer_pool_pages_total');
	my($page_cache_usage) = $innodb_buffer_pool_pages_free * 100 / $innodb_buffer_pool_pages_total;
	return sprintf("%.2f", $page_cache_usage);
}

sub innodb_bp_hit_ratio {
	my($innodb_buffer_pool_reads)=&get_live_value('innodb_buffer_pool_reads');
	my($innodb_buffer_pool_read_requests)=&get_live_value('innodb_buffer_pool_read_requests');
	my($hit_ratio) = 100 - ($innodb_buffer_pool_reads * 100 / $innodb_buffer_pool_read_requests);
	return sprintf("%.2f", $hit_ratio);
}

sub tmp_table_ratio {
	my($created_tmp_disk_tables)=&get_live_value('created_tmp_disk_tables');
	my($created_tmp_tables)=&get_live_value('created_tmp_tables');
	my($ratio) = $created_tmp_disk_tables * 100 / $created_tmp_tables;
	return sprintf("%.2f", $ratio);
}

sub qps {
	# per http://mysqldump.azundris.com/archives/68-Monitoring-MySQL.html
	# The following is a more accurate representation of "useful" or application
	# queries per second
	my($com_select)=&get_live_value('com_select');
	my($qcache_hits)=&get_live_value('qcache_hits');
	my($com_insert)=&get_live_value('com_insert');
	my($com_update)=&get_live_value('com_update');
	my($com_delete)=&get_live_value('com_delete');
	my($com_replace)=&get_live_value('com_replace');
	my($uptime)=&get_live_value('uptime');
	my($total_questions) = $com_select + $qcache_hits + $com_insert + $com_update + $com_delete + $com_replace;
	my $qps = $total_questions / $uptime;
	return sprintf("%.2f", $qps);
}

sub print_usage {
	print "Usage: $0 -H <host> -U <username> -P <password> -w <warn level> -c <crit level> [-i|-q|-p|-t|-Q]\n"
}

sub help {
	print "\nMySQL Performance Monitor Script for Nagios\n";
	print_usage();
	print <<EOT;
-h, --help
	print this help message
-H, --hostname=HOST
	name or IP address of host to check
-U, --username=USERNAME
	username to connect to the database
	* MUST have permissions to execute "SHOW GLOBAL VARIABLES" and "SHOW GLOBAL STATUS"
-P, --password=PASSWORD
	password of username connecting to the database
-i, --innodbbp
	check InnoDB bufferpool hit ratio 
	- Returns percentage value
-q, --qps
	check queries per second 
	- Returns single value
-p, --innodbpc
	check InnoDB page cache usage
	- Returns percentage value
-t, --threadcache
	check thread cache hit ratio
	- Returns percentage value
-Q, --querycache
	check query cache hit ratio
	- Returns percentage value
-C, --connections
	check percentage of max connections in use
	- Returns percentage value
-c, --crit
	critical value 
		(<= for options i,t,Q)
		(>= for options q,C,p)
-w, --warn
	warning value
		(<= for options i,t,Q)
		(>= for options q,C,p)

**********************************************************************************
For options [i,p,t,Q], warning and critical are lowest values acceptable i.e.
	If bufferpool hit ratio falls BELOW warn/crit value, alarms will be raised
For option [q], warning and critical are maximum values acceptable i.e.
	If queries per second goes ABOVE warn/crit value, alarms will be raised
**********************************************************************************
EOT
}

sub check_options {
	Getopt::Long::Configure ("bundling");
		GetOptions (
		'h'	=> \$o_help,			'help'		=> \$o_help,
		'H:s'	=> \$o_hostname,		'hostname:s'	=> \$o_hostname,
		'U:s'	=> \$o_username,		'username:s'	=> \$o_username,
		'P:s'	=> \$o_password,		'password:s'	=> \$o_password,
		'i'	=> \$o_bufferpool,		'innodbbp'	=> \$o_bufferpool,
		'q'	=> \$o_qps,			'qps'		=> \$o_qps,
		'p'	=> \$o_pagecache,		'innodbpc'	=> \$o_pagecache,
		't'	=> \$o_threadcache,		'threadcache'	=> \$o_threadcache,
		'Q'	=> \$o_querycache,		'querycache'	=> \$o_querycache,
		'C'	=> \$o_connections,		'connections'	=> \$o_connections,
		'c:i'	=> \$o_crit,			'crit:i'		=> \$o_crit,
		'w:i'	=> \$o_warn,			'warn:i'		=> \$o_warn
	);
	if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
	if ( !defined($o_hostname) )
		{ print "No host defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
	if ( !defined($o_username) )
		{ print "No username defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
	if ( !defined($o_password) )
		{ print "No password defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
	if ( !defined($o_bufferpool) && !defined($o_qps) && !defined($o_pagecache) && !defined($o_threadcache) && !defined($o_querycache) && !defined($o_connections) )
		{ print "A monitor must be defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
	if ( !defined($o_warn) && !defined($o_crit) )
		{ print "Warning and Critical levels must be defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
}

## Main ##
check_options();

my %cache_options = ('namespace'=>$o_hostname);
$cache = new Cache::SharedMemoryCache(\%cache_options)
	or die "Cannot instatiate ShareMemoryCache: $_\n";

if (defined($o_bufferpool)) {
	if ( $o_crit != 0 && $o_warn < $o_crit )
		{ print "Warning level should be higher than crit for hit ratios!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
	$results = innodb_bp_hit_ratio()
		or die $ERRORS{"UNKNOWN"};
	$n_perfdata=" hit_ratio=$results;$o_warn;$o_crit;0;100";
	if ($results <= $o_crit) {
		$n_status="CRITICAL";
	} elsif ($results <= $o_warn) {
		$n_status="WARNING";
	} else {
		$n_status="OK";
	}
	$n_output="$n_status: Bufferpool hit ratio is $results% | " . $n_perfdata;
	
}
if (defined($o_qps)) {
	if ( $o_crit != 0 && $o_warn > $o_crit )
		{ print "Warning level should be lower than crit for single values!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
	$results = qps()
		or die $ERRORS{"UNKNOWN"};
	$n_perfdata=" qps=$results;$o_warn;$o_crit;;";
	if ($results >= $o_crit) {
		$n_status="CRITICAL";
	} elsif ($results >= $o_warn) {
		$n_status="WARNING";
	} else {
		$n_status="OK";
	}
	$n_output="$n_status: Queries per second: $results | " . $n_perfdata;

}
if (defined($o_connections)) {
	if ( $o_crit != 0 && $o_warn > $o_crit )
		{ print "Warning level should be less than crit!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
	$results = connection_use()
		or die $ERRORS{"UNKNOWN"};
	$n_perfdata=" percent_used=$results;$o_warn;$o_crit;0;100";
	if ($results >= $o_crit) {
		$n_status="CRITICAL";
	} elsif ($results >= $o_warn) {
		$n_status="WARNING";
	} else {
		$n_status="OK";
	}
	$n_output="$n_status: Percentage of Connection used is $results% | " . $n_perfdata;
}
if (defined($o_pagecache)) {
	if ( $o_crit != 0 && $o_warn > $o_crit )
		{ print "Warning level should be lower than crit for hit ratios!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
	$results = innodb_page_cache_usage()
		or die $ERRORS{"UNKNOWN"};
	$n_perfdata=" cache_usage=$results;$o_warn;$o_crit;0;100";
	if ($results <= $o_crit) {
		$n_status="CRITICAL";
	} elsif ($results <= $o_warn) {
		$n_status="WARNING";
	} else {
		$n_status="OK";
	}
	$n_output="$n_status: Page cache usage is $results% | " . $n_perfdata;
}
if (defined($o_threadcache)) {
	if ( $o_crit != 0 && $o_warn < $o_crit )
		{ print "Warning level should be higher than crit for hit ratios!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
	$results = tcache_hit_ratio()
		or die $ERRORS{"UNKNOWN"};
	$n_perfdata=" hit_ratio=$results;$o_warn;$o_crit;0;100";
	if ($results <= $o_crit) {
		$n_status="CRITICAL";
	} elsif ($results <= $o_warn) {
		$n_status="WARNING";
	} else {
		$n_status="OK";
	}
	$n_output="$n_status: Thread cache hit ratio is $results% | " . $n_perfdata;
}
if (defined($o_querycache)) {
	if ( $o_crit != 0 && $o_warn < $o_crit )
		{ print "Warning level should be higher than crit for hit ratios!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
	$results = qcache_hit_ratio()
		or die $ERRORS{"UNKNOWN"};
	$n_perfdata=" hit_ratio=$results;$o_warn;$o_crit;0;100";
	if ($results <= $o_crit) {
		$n_status="CRITICAL";
	} elsif ($results <= $o_warn) {
		$n_status="WARNING";
	} else {
		$n_status="OK";
	}
	$n_output="$n_status: Query cache hit ratio is $results% | " . $n_perfdata;
}
print "$n_output \n";
exit $ERRORS{$n_status};
