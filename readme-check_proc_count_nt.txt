This script is useless without the following two items:


1) `NC_Net client <http://www.shatterit.com/nc_nt/>`_
2) `check_nt.c <http://www.shatterit.com/nc_net/files/check_nt.c>`_

The script is pretty straight forward. Use '--help' for a full listing of command line options.

Example nagios checkcommand::

    define command {
           command_name                    check_nt_proc_count
           command_line                    $USER1$/check_proc_count_nt -H $HOSTADDRESS$ -p 1248 -s $USER3$ -n $ARG1$ -c $ARG2$
    }

where 
$USER1$ is the resource macro for your plugin directory 
and 
$USER3$ is the resource macro containing the secret key used to communicate with NC_Net

Example nagios service definition::

    define service {
           service_description             Check Foo Server - Bar processes
           use                             generic-service-template
           host_name                       win2k3std01
           check_command                   check_nt_proc_count!bar.exe!3
    }

