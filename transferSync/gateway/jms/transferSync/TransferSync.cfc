<cfcomponent displayname="TransferSync" output="false" hint="TransferSync ActiveMQ JMS Gateway">

	<!--- PROPERTIES --->
	<cfset this.transfer = '' />
	<cfset this.hostName = createObject('java', 'java.net.InetAddress').getLocalHost().getHostName() & '_' & createObject('java', 'jrunx.kernel.JRun').getServerName() />
	<cfset this.enableLogging = false />
	<cfset this.logPath = 'TransferSync' />
	<cfset this.enableDebug = false />
	<cfset this.debugPath = getDirectoryFromPath(getCurrentTemplatePath()) />
	
	<!--- GATEWAY --->
	<cffunction name="onIncomingMessage" returntype="void" access="public" output="false">
		<cfargument name="event" type="struct" required="true" />
		
		<cfset var stLocal = structNew() />
		
		<cftry>
			<cfset stLocal.message = structNew() />
			<cfset stLocal.message = arguments.event.data.msg />
			<cfset stLocal.status = 'IGNORED' />
			
			<cfif stLocal.message['source'] is not getHostName()>
				<cfset stLocal.status = 'ACKNOWLEDGED' />
				<cfset getTransfer().discardByClassAndKey(stLocal.message['className'],deserializeJSON(stLocal.message['key']))>
			</cfif>
			
			<cfset writeToLog('TransferSync : #stLocal.status# : #stLocal.message.toString()#','information') />
				
			<cfcatch type="any">
				<cfset writeToLog('TransferSync : ERROR : GATEWAY : #cfcatch.toString()#') />
				<cfset writeDebug(cfcatch,arguments,stLocal,getHostName()) />
			</cfcatch>
		</cftry>
	</cffunction>
	
	<!--- PRIVATE --->
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
			<cfset stLocal.sFilePath = getDebugPath() & "\transferSync_gateway_#createUUID()#.htm" />
			<cfset writeToLog('Debug Info Written To #stLocal.sFilePath#') />
			
			<cfsavecontent variable="stLocal.dumpArgs">
				<cfdump var="#arguments#" />
			</cfsavecontent>
			<cffile action="write" file="#stLocal.sFilePath#" output="#stLocal.dumpArgs#" />
		</cfif>
	</cffunction>
	
	<!--- GETTERS --->
	<cffunction name="getTransfer" access="private" returntype="transfer.com.transfer" output="false">
		<cfreturn this.transfer />
	</cffunction>
	
	<cffunction name="getVersion" access="public" returntype="string" output="false">
		<cfreturn "0.6" />
	</cffunction>
	
	<cffunction name="getHostName" access="public" returntype="string" output="false">
		<cfreturn this.hostName />
	</cffunction>
	
	<cffunction name="getEnableLogging" access="public" returntype="boolean" output="false">
		<cfreturn this.enableLogging />
	</cffunction>
	
	<cffunction name="getLogPath" access="public" returntype="string" output="false">
		<cfreturn this.logPath />
	</cffunction>
	
	<cffunction name="getEnableDebug" access="public" returntype="boolean" output="false">
		<cfreturn this.enableDebug />
	</cffunction>
	
	<cffunction name="getDebugPath" access="public" returntype="string" output="false">
		<cfreturn this.debugPath />
	</cffunction>
	
</cfcomponent>