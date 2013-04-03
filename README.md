This is just some old code I wrote a long time ago. Most of it is Nagios related. It likely doesn't even work anymore.

The original source for these files is [http://dev.lusis.org/nagios/](here).

# Quick rundown

## `mhs.pl`
This was a health check service I wrote when I was at HWSI. We used it with our Foundry LBs to health-check mysql read slaves.

## `check_cups_queue.sh`
When I was with Community Loans, we had an interesting setup. Because of fraud issues (and the nature of our business), we controlled ALL printing in our stores from our data center. It was actually one of the coolest "hacks" I ever worked on. We had a cluster of CUPS servers behind a CoyotePoint LB. We had roughly 500-600 stores when I left each with a minimum of 2 Jet Direct printers. Some of the larger locations had 5+ printers.

Our loan management application (a java struts app running on websphere) would send the print jobs to the cluster. These might be contracts or checks to print for the customers taking out "loans". Just getting this working was something of a pain in the ass. We went through at least 15 different models of laser printers and various printer driver combos to make this work. We had a heavily hacked version of CUPS and this is the only place I've ever run Gentoo in production. AFAIK it's still running there today almost 11 years later. Some of the stores were on the most god awful internet connections around (satellite, dial-up) so the challenge was getting the resulting print jobs sent by the CUPS server down to something that didn't saturate the connection.

This script was basically what we used to monitor the print queues for each store. 

Side note, the CUPS web interface was unusable with 1500+ printers defined....

## `check_proc_count_nt`
Your basic process count checker for Nagios but to call against Windows servers

## `usable`
Just a few "blog posts" about various monitoring things. For the longest time, the db2+nagios entry was the first hit on google for monitoring db2 with nagios. Still kinda proud about that.
