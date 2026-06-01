The file data/backup/tickdemo.tgz contains the test data for the mserve tick demo in the form of 
log files written by tick.q from a year's worth of random data created by feed.q.
Note: this is not included in the repo and must be downloaded separately. It is about 5.5G compressed.

Use of this dataset should ensure you get similar results to those we describe in the report.
To restore to the starting point for the demo:

1. Clear any old deployment
1.1. Delete all content from the data/log and data/archive directories on the mserve machine. (no hdb there)
1.2. Delete all content fron the data/log and data/hdb directories on each hdb servant. (no archive there)
1.3. Delete all content from the data/log directory on each rdb servant (no hdb or archive there)

2. Unpack the backup: [ cd data; tar -xvzf tickdemo.tgz ] on the mserve machine
2.1. Move data/backup/feed.hiw.save to data/log/feed.hiw 

3. Start launcher.q on each remote hdb host: [ q launcher.q 172.30.1.205 - data/log -p 5999 ]
4. Allow the rsync job to finish copying ALL log files from dev1 onto the remote host, then quit launcher.q.

5. Start hdb.q on each remote hdb host, in "restore mode": [ q hdb.q schema data/log data/hdb restore ]
  This builds the hdb from the log files, but deletes each log after it has been applied, so disk does not fill up.
  Note: hdb.q quits automatically when "restore" is specified, and the build is finished.

6. Check the result on each remote hdb host
6.1. data/log should contain  a file for the most recent 3 days.
6.2. data/hdb should contain  a directory for all but the most recent 2 days.
6.3. The third most recent date should be in both the log and hdb.
6.4. Start hdb.q as the "A" instance: [ q hdb.q schema data/log data/hdb A ]
6.5. Try a couple api functions from the hdb.q console (e.g. api.vwap[-92 -2; `])

7. Move all but the most recent 3 days from the log to archive directories.

8. Start launcher.q on each remote servant  [ q launcher.q 172.30.1.205 - data/log -p 5999 ]
 The rsync job will copy the 3 files in the log directory from the mserve machine to the servant.
 At this point you are ready to run the demo.

After running the demo for a while with data comming in the disk will fill up.
So the data/log/feed.hiw file has a stop timestamp.
Feed.q stops when the start timestamp reaches the stop timestamp.

To reset the data to a point before this happened, so you can run with data comming in again:

1. Run the script "resetServantData" on each remote hdb host.
2. Run the script "resetUbuntuData" on dev 1.
3. Start launcher.q on each remote host (rdb too).
4. Check that the data has been reset correctly (see note below). 

Note: The scripts are customized to the particular data used in the demo, and contained in the backup.
This means a year of  data, from 2025.10.01 through 2026.09.30.
The starting point must have:
1.  all but the last 3 days (2026.09.28, 29, 30) in the archive.
2.  all but the last 2 days (2026.09.29, 30) in the hdb.
3.  the last 3 days in the log.

