<cfcomponent displayname="TransferSyncObserver" hint="This is the TransferSync component" output="false">

	<cffunction name="init" access="public" returntype="TransferSyncObserver">
		<cfargument name="transfer" type="transfer.com.Transfer" required="true" />
		<cfargument name="keyRetriever" type="any" required="true" />
		<cfargument name="gatewayName" type="string" required="true" />
		<cfargument name="JMSTopic" type="string" required="true" />
		<cfargument name="enableLogging" type="boolean" required="false" default="false" />
		<cfargument name="logPath" type="string" required="false" default="TransferSync" />
		<cfargument name="enableDebug" type="boolean" required="false" default="false" />
		<cfargument name="debugPath" type="string" required="false" default="#getDirectoryFromPath(getCurrentTemplatePath())#" />
		<cfargument name="enableOnInit" type="boolean" required="false" default="true" />
		<cfargument name="excludeList" type="string" required="false" default="" />
		<cfargument name="enableCachedParents" type="boolean" required="false" default="true" />
		
		<cfset variables.instance = structNew() />
		<cfset variables.instance.cachedParents = structNew() />
		
		<cfset setHostName(createObject('java', 'java.net.InetAddress').getLocalHost().getHostName() & '_' & createObject('java', 'jrunx.kernel.JRun').getServerName()) />
		
		<cfset setTransfer(arguments.transfer) />
		<cfset setKeyRetriever(arguments.keyRetriever) />
		<cfset setGatewayName(arguments.gatewayName) />
		<cfset setJMSTopic(arguments.JMSTopic) />
		<cfset setEnableLogging(arguments.enableLogging) />
		<cfset setLogPath(arguments.logPath) />
		<cfset setEnableDebug(arguments.enableDebug) />
		<cfset setDebugPath(arguments.debugPath) />
		<cfset setEnableOnInit(arguments.enableOnInit) />
		<cfset setExcludeList(arguments.excludeList) />
		<cfset setEnableCachedParents(arguments.enableCachedParents) />
		
		<cfif getEnableOnInit()>
			<cfset enableObserver() />
		</cfif>
		<cfreturn this />
	</cffunction>
	
	<!--- TRANSFER EVENTS --->	
	<cffunction name="actionAfterCreateTransferEvent" returntype="void" access="public" output="false">
		<cfargument name="event" type="transfer.com.events.TransferEvent" hint="The event object" required="true" />
		<cfset sendSynchronizationMessage(arguments.event.getTransferObject(),'afterCreate') />
	</cffunction>

	<cffunction name="actionAfterUpdateTransferEvent" returntype="void" access="public" output="false">
		<cfargument name="event" type="transfer.com.events.TransferEvent" hint="The event object" required="true" />
		<cfset sendSynchronizationMessage(arguments.event.getTransferObject(),'afterUpdate') />
	</cffunction>
	
	<cffunction name="actionAfterDeleteTransferEvent" returntype="void" access="public" output="false">
		<cfargument name="event" type="transfer.com.events.TransferEvent" hint="The event object" required="true" />
		<cfset sendSynchronizationMessage(arguments.event.getTransferObject(),'afterDelete') />
	</cffunction>
	
	<!--- PUBLIC --->
	<cffunction name="enableObserver" access="public" returntype="void" output="false">
		<!--- inject into transfer --->
		<cfset getTransfer().addAfterCreateObserver(this) />
		<cfset getTransfer().addAfterUpdateObserver(this) />
		<cfset getTransfer().addAfterDeleteObserver(this) />
		<!--- log --->
		<cfset writeToLog("TransferSync : #getGatewayName()# : OBSERVER : ENABLED","information") />
	</cffunction>
	
	<cffunction name="disableObserver" access="public" returntype="void" output="false">
		<!--- remove from transfer --->
		<cfset getTransfer().removeAfterCreateObserver(this) />
		<cfset getTransfer().removeAfterUpdateObserver(this) />
		<cfset getTransfer().removeAfterDeleteObserver(this) />
		<!--- log --->
		<cfset writeToLog("TransferSync : #getGatewayName()# : OBSERVER : DISABLED","information") />
	</cffunction>
	
	<!--- PRIVATE --->
	<cffunction name="sendSynchronizationMessage" returntype="void" access="private" output="false" 
				hint="I send the cache synchronization message.">
		<cfargument name="transferObject" type="any" required="true" />
		<cfargument name="transferEvent" type="any" required="true" />
		
		<cfset var stLocal = structNew() />
		
		<cftry>
			<!--- check against exclude list --->
			<cfif len(getExcludeList()) and listFindNoCase(getExcludeList(),arguments.transferObject.getClassName())>
				<!--- log --->
				<cfset writeToLog("TransferSync : #getGatewayName()# : EXCLUDED : #arguments.transferObject.getClassName()# is in the exclude list.","information") />
			<cfelse>
				<!--- build message --->
				<cfset stLocal.message = structNew() />
				<cfset stLocal.message['source'] = getHostName() />
				<cfset stLocal.message['transferEvent'] = arguments.transferEvent />
				<cfset stLocal.message['className'] = arguments.transferObject.getClassName() />
				<cfset stLocal.message['key'] = serializeJSON(getKeyRetriever().getKey(arguments.transferObject)) />
				
				<!--- build event data --->
				<cfset stLocal.eventData = structNew() />
				<cfset stLocal.eventData['status'] = 'SEND' />
				<cfset stLocal.eventData['topic'] = getJMSTopic() />
				<cfset stLocal.eventData['message'] = stLocal.message />
				
				<!--- send messages --->
				<cfset sendGatewayMessage(getGatewayName(),stLocal.eventData) />
				
				<!--- log --->
				<cfset writeToLog("TransferSync : #getGatewayName()# : #stLocal.eventData['status']# : #stLocal.message.toString()#","information") />
			</cfif>
			
			<!--- notify parents one level up --->
			<cfif listLast(arguments.transferEvent,'-') neq 'parent'>
				<cfset notifyParents(argumentCollection = arguments) />
			</cfif>
			
			<!--- log error and write debug info --->
			<cfcatch type="any">
				<cfset writeToLog('TransferSync : #getGatewayName()# : ERROR : OBSERVER : #cfcatch.toString()#') />
				<cfset writeDebug(cfcatch,arguments,stLocal,getHostName()) />
			</cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="notifyParents" output="false" returntype="void" access="private">
		<cfargument name="transferObject" type="any" required="true" />
		<cfargument name="transferEvent" type="any" required="true" />
		
		<cfset var stLocal = structNew() />
		
		<!--- check cache --->
		<cfif hasCachedParent(arguments.transferObject.getClassName())>
			<!--- load parents from cache --->
			<cfset stLocal.aParents = getCachedParents(arguments.transferObject.getClassName()) />
			<cfloop from="1" to="#arrayLen(stLocal.aParents)#" index="stLocal.i">
				<!--- load parent object dynamically --->
				<cfset stLocal.oParent = evaluate('arguments.transferObject.getParent#stLocal.aParents[stLocal.i]#()') />
				<!--- send sync message --->
				<cfset sendSynchronizationMessage(stLocal.oParent,arguments.transferEvent & '-parent') />
			</cfloop>
		<cfelse>
			<!--- check for one to many parents --->
			<cfif getTransfer().getTransferMetaData(arguments.transferObject.getClassName()).hasParentOneToMany()>
				<cfset stLocal.oIterator = getTransfer().getTransferMetaData(arguments.transferObject.getClassName()).getParentOneToManyIterator() />
				<cfloop condition="#stLocal.oIterator.hasNext()#">
					<cfset stLocal.oParentMeta = stLocal.oIterator.next() />
					<cfset stLocal.sParentName = stLocal.oParentMeta.getLink().getToObject().getObjectName() />
					<!--- load parent object dynamically --->
					<cfset stLocal.oParent = evaluate('arguments.transferObject.getParent#stLocal.sParentName#()') />
					<!--- add to cache --->
					<cfset addCachedParent(arguments.transferObject.getClassName(),stLocal.sParentName) />
					<!--- send sync message --->
					<cfset sendSynchronizationMessage(stLocal.oParent,arguments.transferEvent & '-parent') />
				</cfloop>
			</cfif>
			
			<!--- check for many to many parents --->
			<cfif getTransfer().getTransferMetaData(arguments.transferObject.getClassName()).hasParentManyToMany()>
				<cfset stLocal.oIterator = getTransfer().getTransferMetaData(arguments.transferObject.getClassName()).getParentManyToManyIterator() />
				<cfloop condition="#stLocal.oIterator.hasNext()#">
					<cfset stLocal.oParentMeta = stLocal.oIterator.next() />
					<cfset stLocal.sParentName = stLocal.oParentMeta.getLink().getToObject().getObjectName() />
					<!--- load parent object dynamically --->
					<cfset stLocal.oParent = evaluate('arguments.transferObject.getParent#stLocal.sParentName#()') />
					<!--- add to cache --->
					<cfset addCachedParent(arguments.transferObject.getClassName(),stLocal.sParentName) />
					<!--- send sync message --->
					<cfset sendSynchronizationMessage(stLocal.oParent,arguments.transferEvent & '-parent') />
				</cfloop>
			</cfif>
		</cfif>
	</cffunction>
	
	<cffunction name="hasCachedParent" access="private" returntype="boolean" output="false">
		<cfargument name="className" type="string" required="true" />
		<cfreturn (getEnableCachedParents() and structKeyExists(variables.instance.cachedParents,arguments.className)) />
	</cffunction>
	
	<cffunction name="addCachedParent" access="private" returntype="void" output="false">
		<cfargument name="className" type="string" required="true" />
		<cfargument name="parentName" type="string" required="true" />
		<cfif getEnableCachedParents()>
			<cfif not structKeyExists(variables.instance.cachedParents,arguments.className)>
				<cfset variables.instance.cachedParents[arguments.className] = arrayNew(1) />
			</cfif>
			<cfset arrayAppend(variables.instance.cachedParents[arguments.className],arguments.parentName) />
		</cfif>
	</cffunction>
	
	<cffunction name="getCachedParents" access="private" returntype="array" output="false">
		<cfargument name="className" type="string" required="true" />
		<cfreturn variables.instance.cachedParents[arguments.className] />
	</cffunction>
	
	<cffunction name="writeToLog" access="private" returntype="void" output="false">
		<cfargument name="message" type="string" required="true" />
		<cfargument name="type" type="string" required="false" default="error" />
		<cfif getEnableLogging() and len(getLogPath())>
			<cflog application="true" file="#getLogPath()#" text="#arguments.message#" type="#arguments.type#" />
		</cfif>
	</cffunction>
	
	<cffunction name="writeDebug" access="private" returntype="void" output="false">
		<cfset var stLocal = structNew() />
		
		<cfif getEnableDebug() and len(getDebugPath()) and directoryExists(getDebugPath())>
			<cfset stLocal.sFilePath = getDebugPath() & "\transferSync_observer_#createUUID()#.htm" />
			<cfset writeToLog('Debug Info Written To #stLocal.sFilePath#') />
			
			<cfsavecontent variable="stLocal.dumpArgs">
				<cfdump var="#arguments#" />
			</cfsavecontent>
			<cffile action="write" file="#stLocal.sFilePath#" output="#stLocal.dumpArgs#" />
		</cfif>
	</cffunction>
	
	<!--- GETTERS AND SETTERS --->
	<cffunction name="getVersion" access="public" returntype="string" output="false">
		<cfreturn "0.5" />
	</cffunction>
	
	<cffunction name="getMemento" access="public" returntype="struct" output="false">
		<cfreturn variables.instance />
	</cffunction>
	
	<cffunction name="setMemento" access="public" returntype="void" output="false">
		<cfargument name="memento" type="struct" required="true" />
		<cfset variables.instance = arguments.memento />
	</cffunction>
	
	<cffunction name="getTransfer" access="public" returntype="transfer.com.Transfer" output="false">
		<cfreturn variables.instance.transfer />
	</cffunction>
	
	<cffunction name="setTransfer" access="public" returntype="void" output="false">
		<cfargument name="transfer" type="transfer.com.Transfer" required="true" />
		<cfset variables.instance.transfer = arguments.transfer />
	</cffunction>
	
	<cffunction name="getKeyRetriever" access="public" returntype="any" output="false">
		<cfreturn variables.instance.keyRetriever />
	</cffunction>
	
	<cffunction name="setKeyRetriever" access="public" returntype="void" output="false">
		<cfargument name="keyRetriever" type="any" required="true" />
		<cfset variables.instance.keyRetriever = arguments.keyRetriever />
	</cffunction>
	
	<cffunction name="getHostName" access="public" returntype="string" output="false">
		<cfreturn variables.instance.hostName />
	</cffunction>
	
	<cffunction name="setHostName" access="public" returntype="void" output="false">
		<cfargument name="hostName" type="string" required="true" />
		<cfset variables.instance.hostName = arguments.hostName />
	</cffunction>
	
	<cffunction name="getGatewayName" access="public" returntype="string" output="false">
		<cfreturn variables.instance.gatewayName />
	</cffunction>
	
	<cffunction name="setGatewayName" access="public" returntype="void" output="false">
		<cfargument name="gatewayName" type="string" required="true" />
		<cfset variables.instance.gatewayName = arguments.gatewayName />
	</cffunction>
	
	<cffunction name="getJMSTopic" access="public" returntype="string" output="false">
		<cfreturn variables.instance.JMSTopic />
	</cffunction>
	
	<cffunction name="setJMSTopic" access="public" returntype="void" output="false">
		<cfargument name="JMSTopic" type="string" required="true" />
		<cfset variables.instance.JMSTopic = arguments.JMSTopic />
	</cffunction>
	
	<cffunction name="getEnableLogging" access="public" returntype="boolean" output="false">
		<cfreturn variables.instance.enableLogging />
	</cffunction>
	
	<cffunction name="setEnableLogging" access="public" returntype="void" output="false">
		<cfargument name="enableLogging" type="boolean" required="true" />
		<cfset variables.instance.enableLogging = arguments.enableLogging />
	</cffunction>
	
	<cffunction name="getLogPath" access="public" returntype="string" output="false">
		<cfreturn variables.instance.logPath />
	</cffunction>
	
	<cffunction name="setLogPath" access="public" returntype="void" output="false">
		<cfargument name="logPath" type="string" required="true" />
		<cfset variables.instance.logPath = arguments.logPath />
	</cffunction>
	
	<cffunction name="getEnableDebug" access="public" returntype="boolean" output="false">
		<cfreturn variables.instance.enableDebug />
	</cffunction>
	
	<cffunction name="setEnableDebug" access="public" returntype="void" output="false">
		<cfargument name="enableDebug" type="boolean" required="true" />
		<cfset variables.instance.enableDebug = arguments.enableDebug />
	</cffunction>
	
	<cffunction name="getDebugPath" access="public" returntype="string" output="false">
		<cfreturn variables.instance.debugPath />
	</cffunction>
	
	<cffunction name="setDebugPath" access="public" returntype="void" output="false">
		<cfargument name="debugPath" type="string" required="true" />
		<cfset variables.instance.debugPath = arguments.debugPath />
	</cffunction>
	
	<cffunction name="getEnableOnInit" access="public" returntype="boolean" output="false">
		<cfreturn variables.instance.enableOnInit />
	</cffunction>
	
	<cffunction name="setEnableOnInit" access="public" returntype="void" output="false">
		<cfargument name="enableOnInit" type="boolean" required="true" />
		<cfset variables.instance.enableOnInit = arguments.enableOnInit />
	</cffunction>	
	
	<cffunction name="getExcludeList" access="public" returntype="string" output="false">
		<cfreturn variables.instance.excludeList />
	</cffunction>
	
	<cffunction name="setExcludeList" access="public" returntype="void" output="false">
		<cfargument name="excludeList" type="string" required="true" />
		<cfset variables.instance.excludeList = arguments.excludeList />
	</cffunction>
	
	<cffunction name="getEnableCachedParents" access="public" returntype="boolean" output="false">
		<cfreturn variables.instance.enableCachedParents />
	</cffunction>
	
	<cffunction name="setEnableCachedParents" access="public" returntype="void" output="false">
		<cfargument name="enableCachedParents" type="boolean" required="true" />
		<cfset variables.instance.enableCachedParents = arguments.enableCachedParents />
	</cffunction>
	
</cfcomponent>