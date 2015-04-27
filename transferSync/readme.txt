TransferSync
version: 0.6
date: 9/19/2009

-overview-
TransferSync is a JMS Gateway for ColdFusion, 
built to synchronize Transfer's native cache across a cluster.

- notice -
There is one edge case where transferSync is not useful.
When you change the parent of an existing composite key object there is no way of tracking the original parent.
You would need that parent's id to sync the other nodes after the change is saved.
This should not be common, as changing the parent would mean changing the PK, just delete and create a new one in this case.

-usage-
The TransferSyncObserver is injected into Transfer, and is triggered after a Create, Update, or Delete event is processed.
It uses ColdFusion's JMS event gateway to send a message to the JMS server, which will broadcast it to all listening nodes.
The TransferSync JMS Gateway will update the local cache when a message is received.

-requirements-
- CF8 (uses deserializeJSON / Coldbox version can be used on earlier versions of CF)
- Transfer ORM (v1.1 for composite key support)
- ActiveMQ (free, link provided)

-installation-
1. download activemq jms server
	http://activemq.apache.org
	I recommend running the latest 5.x version for the server side (service).
	If you aren't running CF8 on the default Java 1.6 JRE then you will need the JAR from the ActiveMQ 4.1.X.
	You may need to download both while you are there. However, some have had success with the 5.x jar.

2. place the jar in to a cf8 lib path and restart CF
	(the jar is in the root of the activemq folder you extracted)

3. launch jms server / install service
	-based on OS and preference (refer to activeMQ docs)

4. update the properties in the config file (/gateway/jms/transferSync/TransferSync.cfg)
	- each app / topic requires a config (TransferSync_app1.cfg, TransferSync_app2.cfg)

5. update the properties in the gateway file (/gateway/jms/transferSync/TransferSync.cfc)
	- available to all apps, no need for duplication
	
6. add gateway instance in CF Administrator
	- id:  TransferSync or TransferSync_appName
	- type: ActiveMQ
	- CFC path: (PATH TO TRANSFERSYNC.CFC)
	- CFG path: (PATH TO TRANSFERSYNC.CFG)
	- mode: auto
	
- integration -
The model.transfer.TransferSyncObserver, needs to be initialized and the observer needs to be enabled.

BASIC:
Open the file and inspect the init arguments for available options and required elements.
Once configured and instantiated, it will automatically send messages using the TransferSync gateway.

WITH COLDSPRING:
1. add objects to coldspring config file (sample can be found in the extras folder)
2. set values for GatewayName and JMS Topic

WITH COLDBOX:
1. Use the TransferSync_coldbox.cfc in the /gateway/jms/transferSync folder as the JMS gateway. (Overwrite the gateway/jms/transferSync/TransferSync.cfc)
2. If using coldspring there is a sample definition in the /config/coldspring.xml.
3. Add the SETTINGS in the /config/coldbox.xml to your coldbox config file.
*** There is an issue with app-specific mappings and this version of the gateway, since it extends the coldboxproxy, set the mapping in CF Admin to resolve, or monitor logs to see if it effects your app.

-infrastructure-
There are a few options on infrastructure.

Method 1 - Decentralized JMS:
Installing the ActiveMQ JMS server on each CF instance.
The TransferSync.cfg, by default, points to http://localhost:61616 as the Provider URL.
You do not have to add the IPs of the other nodes to this list, 
as long as ActiveMQ has auto-discovery option enabled. (it is by default in version 5.1.x)

Method 2 - Centralized JMS:
Running the JMS on one machine, and setting the ProviderURL in the TransferSync.cfg file to point to it from each node.
If the JMS machine goes down, and you don't have a redundant fail over, then you have a single point of failure.
Not good. If you do have a fail over machine, then it's not as bad.

**NOTES**
The ActiveMQ server is very light. It takes up about 2MB of RAM, and very little CPU when it's working.

Errors will be logged, so be sure to keep an eye on your CF logs.
Logging and debug info can be enabled/disabled in the TransferSync gateway file.
Either as a property or if using the Coldbox version, it is in your config settings.
It is recommended to disable it on production, as it adds overhead.

**COMING SOON**
-better documentation
-pre-cf8 version without coldbox
-logging adapter

**CREDITS**
Inspired by Sean Corfield's CacheSynchronizer.cfc

Thanks to:
Rob Gonda
Mark Mandel
Luis Majano
Brian Ghidinelli
Dylan ?

0.6 -CHANGE LOG- 9/19/2009
- enhancement - added support for multiple instances on same server

0.5 -CHANGE LOG- 3/9/2009
- enhancement - added observer toggle no longer dependent on lazy init
- enhancement - added debug toggle
- enhancement - added class filtering
- enhancement - added caching for parents
- enhancement - added getMemento and getVersion
- enhancement - more robust logging
- enhancement - coldbox versions supports pre-cf8
- fix - added support for after create events
- fix - added support for notifying parent classes

0.4 -CHANGE LOG- 11/13/2008
- enhancement - logging improvements and toggle setting/property added
- enhancement - improved caching
- enhancement - added getKeyMap method
- enhancement - added argument to definition file
- enhancement - changed definition file extension to .transfer
- fix - added double lock to prevent concurrency issues with duplicate method creation

0.3 -CHANGE LOG- 9/8/2008
- enhancement - added additional properties to gateway for maintainability
- fix - added try\catch around sending message to log if an error occurs or gateway is unavailable
- fix - moved 'ACKNOWLEDGED' logging to after discard to prevent false positives

0.2 -CHANGE LOG- 8/19/2008
- enhancement - added Coldbox version