check_cups_queue can query the status of a CUPS print server on a local or remote print server. Optionally, the age of jobs in the queue can be checked for age (user defined - in days). Any jobs older than X days will alert as critical. Also outputs performance data.

Requires 'lpadmin' from CUPS package on system running the script and mktemp.

Usage:: 
    
    check_cups_queue -H -T -w -c -a

Notes::

     -H: Hostname - Can be a hostname or IP address
     -T: Type of check - Can be queue size (s) or both queu size and queue age (b)
     -w: WARNING level for queue size
     -c: CRITICAL level for queue size
     -a: Max age of queue. Returns CRITICAL if jobs exists older than days

Example output without age check::

    ./check_cups_queue -H prodcups01 -T s -w 50 -c 100
    OK: CUPS queue size - 3| print_jobs=3;50;100;0

Example output with age check (-a)::

    ./check_cups_queue -H prodcups01 -T b -w 50 -c 100 -a 0
    CRITICAL: Some CUPS jobs are older than 0 days| print_jobs=4;50;100;0

Example warning output::

    WARNING: CUPS queue size - 5| print_jobs=5;3;10;0

Example critical output::

    CRITICAL: CUPS queue size - 4| print_jobs=4;1;2;0

Example check_command::

    define command {
        command_name check_cups_queue
        command_line $USER4$/new/check_cups_queue -H $HOSTADDRESS$ -T b -w $ARG1$ -c $ARG2$ -a $ARG3$
    }

Example service definition::

    define service {
        service_description Check CUPS Print Queue
        use generic-service-template
        host_name prodcups02.clacorp.com
        check_command check_cups_queue!50!100!1
    }

