This script is a shortend version of the script we use on our AIX servers to monitor connection count. The actual script has quite a bit more information in it.

For instance, when we go over our warning or critical limits, the DBAs have asked us to perform "snapshots" of the database and store that information on the filesystem. You can include these in your scripts or as part of Nagios as an event handler.

Here's a few sample lines from our snapshots

    ::

        echo "Snapshot directory found. Performing snapshots" >> $LOGFILE
        echo "Getting db snapshot..." >> $LOGFILE
        sudo -u db2inst1 -H db2 get snapshot for db on PROD > $SNAPSHOTDIR/${SNAPSHOTDATE}-dbsnapshot.out
        echo "Getting dbm snapshot..." >> $LOGFILE
        sudo -u db2inst1 -H db2 get snapshot for dbm > $SNAPSHOTDIR/${SNAPSHOTDATE}-dbmsnapshot.out
        echo "Getting dynamic SQL snapshot..." >> $LOGFILE
        sudo -u db2inst1 -H db2 get snapshot for dynamic sql on PROD > $SNAPSHOTDIR/${SNAPSHOTDATE}-dynamicsql.out
        echo "Getting application snapshot..." >> $LOGFILE
        sudo -u db2inst1 -H db2 get snapshot for applications on PROD > $SNAPSHOTDIR/${SNAPSHOTDATE}-applications.out
        echo "Getting lock snapshot..." >> $LOGFILE
        sudo -u db2inst1 -H db2 get snapshot for locks on PROD > $SNAPSHOTDIR/${SNAPSHOTDATE}-locks.out
        echo "Snapshots created in ${SNAPSHOTDIR}" >> $LOGFILE

These are dumped to a directory structure based on date:

    i.e. "2006/06/06/"

.. footer:: footer.txt
