<cfcomponent displayname="TransferKeyRetriever" hint="This is the TransferKeyRetriever component" output="false">
	
	<cffunction name="init" access="public" returntype="TransferKeyRetriever">
		<cfargument name="transfer" type="transfer.com.Transfer" required="true" />
		<cfargument name="definitionPath" type="string" required="true" />
		
		<cfset variables.instance = structNew() />
		<cfset variables.instance.keyDetail = structNew() />
		<cfset variables.instance.oTransfer = arguments.transfer />
		<cfset variables.instance.sDefinitionPath = arguments.definitionPath />
		
		<cfreturn this />
	</cffunction>
	
	<!--- PUBLIC --->
	<cffunction name="getKey" access="public" output="false" returntype="any">
		<cfargument name="transferObject" type="any" required="true" />
		
		<cfset var stLocal = structNew() />
		
		<cfset stLocal.sMethodName = 'getKey_' & replace(arguments.transferObject.getClassName(),'.','_','all') />
		
		<cfif not structKeyExists(variables, stLocal.sMethodName)>
			<cflock name="transfersync.transferKeyRetriever.#stLocal.sMethodName#" throwontimeout="true" timeout="60">
				<cfif not structKeyExists(variables, stLocal.sMethodName)>
					<cfset buildKeyDefinition(stLocal.sMethodName,getKeyDetail(arguments.transferObject.getClassName())) />
				</cfif>
			</cflock>
		</cfif>
	
		<cfinvoke method="#stLocal.sMethodName#" returnvariable="stLocal.results">
			<cfinvokeargument name="transferObject" value="#arguments.transferObject#" />
		</cfinvoke>
		
		<cfreturn stLocal.results />
	</cffunction>
	
	<cffunction name="setKeyDetail" access="public" output="false" returntype="void">
		<cfargument name="keyDetail" type="struct" required="true" />
		<cfset instance.keyDetail[arguments.keyDetail['class']] = arguments.keyDetail />
	</cffunction>
	
	<cffunction name="getKeyDetail" access="public" output="false" returntype="struct">
		<cfargument name="className" type="string" required="true" />
		<cfif not structKeyExists(instance.keyDetail,arguments.className)>
			<cfset setKeyDetail(buildKeyDetail(arguments.className)) />
		</cfif>
		<cfreturn instance.keyDetail[arguments.className] />
	</cffunction>
		
	<cffunction name="buildKeyDetail" access="public" output="false" returntype="struct">
		<cfargument name="className" type="string" required="true" />
		
		<cfset var stLocal = structNew() />
		
		<cfset stLocal.results = structNew() />
		<cfset stLocal.results['detail'] = structNew() />
		<cfset stLocal.results['composite'] = false />
		<cfset stLocal.results['class'] = arguments.className />
		<cfset stLocal.oPrimaryKey = getTransfer().getTransferMetaData(arguments.className).getPrimaryKey() />
		
		<cfif stLocal.oPrimaryKey.getIsComposite()>
			<cfset stLocal.results['composite'] = true />
			<cfset stLocal.oIterator = stLocal.oPrimaryKey.getManyToOneIterator() />
			<cfloop condition="#stLocal.oIterator.hasNext()#">
				<cfset stLocal.manyToOne = stLocal.oIterator.next() />
				<cfset stLocal.stKey = structNew() />
				<cfset stLocal.stKey['type'] = stLocal.manyToOne.getLink().getToObject().getPrimaryKey().getType() />
				<cfset stLocal.stKey['column'] = stLocal.manyToOne.getLink().getColumn() />
				<cfset stLocal.stKey['name'] = stLocal.manyToOne.getLink().getToObject().getPrimaryKey().getName() />
				<cfset stLocal.results.detail[stLocal.manyToOne.getName()] = stLocal.stKey />
			</cfloop>
			
			<cfset stLocal.oIterator = stLocal.oPrimaryKey.getParentOneToManyIterator() />
			<cfloop condition="#stLocal.oIterator.hasNext()#">
				<cfset stLocal.parentOneToMany = stLocal.oIterator.next() />
				<cfset stLocal.stKey = structNew() />
				<cfset stLocal.stKey['type'] = stLocal.parentOneToMany.getLink().getToObject().getPrimaryKey().getType() />
				<cfset stLocal.stKey['column'] = stLocal.parentOneToMany.getLink().getToObject().getPrimaryKey().getColumn() />
				<cfset stLocal.stKey['name'] = stLocal.parentOneToMany.getLink().getToObject().getPrimaryKey().getName() />
				<cfset stLocal.results.detail["parent" & stLocal.parentOneToMany.getLink().getToObject().getObjectName()] = stLocal.stKey />
			</cfloop>
		<cfelse>
			<cfset stLocal.stKey = structNew() />
			<cfset stLocal.stKey['type'] = stLocal.oPrimaryKey.getType() />
			<cfset stLocal.stKey['column'] = stLocal.oPrimaryKey.getColumn() />
			<cfset stLocal.stKey['name'] = stLocal.oPrimaryKey.getName() />			
			<cfset stLocal.results.detail[stLocal.oPrimaryKey.getName()] = stLocal.stKey />
		</cfif>
		
		<cfreturn stLocal.results />
	</cffunction>
	
	<cffunction name="getKeyMap" access="public" output="false" returntype="struct">
		<cfargument name="className" type="string" required="true" />
		<cfargument name="valueMap" type="struct" required="true" default="#structNew()#" />
		
		<cfset var stLocal = structNew() />
		<cfset var stReturn = structNew() />
		<cfset var keyDetail = getKeyDetail(arguments.className).detail />
		
		<cfloop collection="#keyDetail#" item="stLocal.iKey">
			<cfif structKeyExists(arguments.valueMap,keyDetail[stLocal.iKey].column)>
				<cfset stReturn[stLocal.iKey] = arguments.valueMap[keyDetail[stLocal.iKey].column] />
			<cfelse>
				<cfset stReturn[stLocal.iKey] = '' />
			</cfif>
		</cfloop>
		
		<cfreturn stReturn />
	</cffunction>
	
	<cffunction name="getKeyValue" access="public" output="false" returntype="any">
		<cfargument name="className" type="string" required="true" />
		<cfargument name="valueMap" type="struct" required="true" default="#structNew()#" />
		
		<cfset var stLocal = structNew() />
		
		<cfset stLocal.keyMap = getKeyMap(arguments.className,arguments.valueMap) />
		<cfset stLocal.keyList = structKeyList(stLocal.keyMap) />
		<cfif listLen(stLocal.keyList) gt 1>
			<cfreturn stLocal.keyMap />
		</cfif>
		
		<cfreturn stLocal.keyMap[stLocal.keyList] />
	</cffunction>
	
	<!--- PRIVATE --->
	<cffunction name="getTransfer" access="private" returntype="transfer.com.Transfer" output="false">
		<cfreturn variables.instance.oTransfer />
	</cffunction>
	
	<cffunction name="getDefinitionPath" access="private" returntype="string" output="false">
		<cfreturn variables.instance.sDefinitionPath />
	</cffunction>
	
	<cffunction name="buildKeyDefinition" access="private" output="false" returntype="any">
		<cfargument name="methodName" type="string" required="true" />
		<cfargument name="keyMap" type="struct" required="true" />
		
		<cfset var stLocal = structNew() />
		
		<cfset stLocal.stKey = arguments.keyMap.detail />
		<cfset stLocal.oBuffer = createObject('component','transfer.com.dynamic.definition.DefinitionBuffer').init() />
		<cfset stLocal.oBuffer.writeCFFunctionOpen(
											name= arguments.methodName,
											access = 'public',
											returnType = 'any') />
		<cfset stLocal.oBuffer.writeCFArgument(
											name = 'transferObject',
											type = 'any',
											required = 'true') />
			
		<cfsavecontent variable="stLocal.sScriptBody">
			<cfoutput>
			var stKey = structNew();
			<cfloop collection="#stLocal.stKey#" item="stLocal.sItem">
				<cfset stLocal.stField = stLocal.stKey[stLocal.sItem] />
				<cfif arguments.keyMap['composite']>
					stKey['#stLocal.sItem#'] = arguments.transferObject.get#stLocal.sItem#().get#stLocal.stField['name']#();
				<cfelse>
					stKey = arguments.transferObject.get#stLocal.stField['name']#();
				</cfif>
			</cfloop>
			return stKey;
			</cfoutput>
		</cfsavecontent>
		
		<cfset stLocal.oBuffer.writeCFScriptBlock(body = stLocal.sScriptBody) />
		<cfset stLocal.oBuffer.writeCFFunctionClose() />
		
		<cfset stLocal.sFileName = arguments.methodName & '_' & createUUID() & '.transfer' />
		<cfset stLocal.sFullPath = getDefinitionPath() & '/' & stLocal.sFileName />
		<cfset stLocal.sExpandedPath = expandPath(stLocal.sFullPath) />
		
		<cffile action="write" file="#stLocal.sExpandedPath#" output="#stLocal.oBuffer.toDefintionString()#" />
		<cfinclude template="#stLocal.sFullPath#" />
		<cffile action="delete" file="#stLocal.sExpandedPath#" />
	</cffunction>

</cfcomponent>