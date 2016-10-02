/**
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
Author: Brad Wood, Luis Majano
Description:
	
This CacheBox provider communicates with a single Memcached node or a 
cluster of Memcached nodes for a distributed and highly scalable cache store.

*/
component name="MemcachedProvider" serializable="false" implements="coldbox.system.cache.ICacheProvider" accessors=true{
	property name="JavaLoader" inject="Loader@cbjavaloader";

	/**
    * Constructor
    */
	function init() {
		//Store our clients at the application level to prevent re-creation since Wirebox scoping may or may not be available
		if( !structKeyExists( application, "memcachedClients" ) ) application[ "memcachedClients" ] =[];
		// prepare instance data
		instance = {
			// provider name
			name 				= "",
			// provider version
			version				= "1.0",
			// provider enable flag
			enabled 			= false,
			// reporting enabled flag
			reportingEnabled 	= false,
			// configuration structure
			configuration 		= {},
			// cacheFactory composition
			cacheFactory 		= "",
			// event manager composition
			eventManager		= "",
			// storage composition, even if it does not exist, depends on cache
			store				= "",
			// the cache identifier for this provider
			cacheID				= createObject('java','java.lang.System').identityHashCode( this ),
			// Element Cleaner Helper
			elementCleaner		= CreateObject("component","coldbox.system.cache.util.ElementCleaner").init( this ),
			// Utilities
			utility				= createObject("component","coldbox.system.core.util.Util"),
			// our UUID creation helper
			uuidHelper			= createobject("java", "java.util.UUID"),
			// Java URI class
			URIClass 			= createObject("java", "java.net.URI"),
			// Java Time Units
			timeUnitClass 		= createObject("java", "java.util.concurrent.TimeUnit"),
			// For serialization of complex values
			converter			= createObject("component","coldbox.system.core.conversion.ObjectMarshaller").init(),
			// Javaloader ID placeholder
			javaLoaderID		= "",
			// The design document which tracks our keys in use
			designDocumentName = 'CacheBox_allKeys' & hash( getCurrentTemplatePath() ),
			// The array of clients which should not exceed the maxThreads config setting
			memcachedClients	= application.memcachedClients
		};

		// JavaLoader Static ID
		instance.javaLoaderID 		= "memcached-provider-#instance.version#-loader";
		
		// Provider Property Defaults
		instance.DEFAULTS = {
			maxThreads = 10
			,defaultTimeoutUnit = "MINUTES"
			,objectDefaultTimeout = 30
            ,opQueueMaxBlockTime = 5000
	        ,opTimeout = 5000
	        ,timeoutExceptionThreshold = 5000
	        ,ignoreMemcachedTimeouts = true
			,bucket = "default"
			,servers = "localhost:11211" // This can be an array
			,username = ""
			,password = ""
			,awsSecretKey : ""
			,awsAccessKey : ""
			,caseSensitiveKeys : true
			,updateStats : true
			,debug = false
		};		
		
		return this;
	}
	
	/**
    * get the cache name
    */    
	any function getName() output="false" {
		return instance.name;
	}
	
	/**
    * get the cache provider version
    */    
	any function getVersion() output="false" {
		return instance.version;
	}
	
	/**
    * set the cache name
    */    
	void function setName(required name) output="false" {
		instance.name = arguments.name;
	}
	
	/**
    * set the event manager
    */
    void function setEventManager(required any EventManager) output="false" {
    	instance.eventManager = arguments.eventManager;
    }
	
    /**
    * get the event manager
    */
    any function getEventManager() output="false" {
    	return instance.eventManager;
    }
    
	/**
    * get the cache configuration structure
    */
    any function getConfiguration() output="false" {
		return instance.config;
	}
	
	/**
    * set the cache configuration structure
    */
    void function setConfiguration(required any configuration) output="false" {
		instance.config = arguments.configuration;
	}
	
	/**
    * get the associated cache factory
    */
    any function getCacheFactory() output="false" {
		return instance.cacheFactory;
	}
		
	/**
    * set the associated cache factory
    */
    void function setCacheFactory(required any cacheFactory) output="false" {
		instance.cacheFactory = arguments.cacheFactory;
	}
		
	/**
    * get the Memcached Client
    */
    any function getMemcachedClient() {

    	var maxInstances = getConfiguration().maxThreads;
    	var clients = instance.memcachedClients;


    	if( arrayLen( clients ) < maxInstances ){
			// lock creation	
			lock name="Provider.config.#instance.cacheID#-#arrayLen( clients )#" type="exclusive" throwontimeout="true" timeout="5"{
	    		
	    		if( !structKeyExists(application,'cbcontroller') || isNull( application.cbController.getWirebox() ) ) throw "Wirebox is required to use this provider";
			
				if( isNull( getJavaLoader() ) ) application.cbController.getWirebox().autowire(this);

				try{
					var ConnectionFactoryBuilder = Javaloader.create( "net.spy.memcached.ConnectionFactoryBuilder" );
					var FailureMode = Javaloader.create( "net.spy.memcached.FailureMode" );
					//if we only have one server set our failover to retry to the current node
					if( arrayLen( instance.config.servers ) == 1 ){					
						ConnectionFactoryBuilder.setFailureMode( FailureMode.RETRY );
					}
					var ConnectionFactory = ConnectionFactoryBuilder.build();
					arrayAppend( clients, Javaloader.create( "net.spy.memcached.MemcachedClient" ).init( ConnectionFactory, instance.config.servers ) );
				} catch( Any e ){
					instance.logger.error("There was an error creating the Memcached Client: #e.message# #e.detail#", e );
					throw(message='There was an error creating the Memcached Client', detail=e.message & " " & e.detail);
				}
			}
				
    	}

    	if( arrayIsEmpty( clients ) )  throw( "MemcachedClient does not exist" );

    	return clients[ RandRange( 1, arrayLen( clients ) ) ];
	}
				
	/**
    * configure the cache for operation
    */
    void function configure() output="false" {

		var config 	= getConfiguration();
		var props	= [];
		var URIs 	= [];
    	var i = 0;
		
		// Prepare the logger
		instance.logger = getCacheFactory().getLogBox().getLogger( this );
		instance.logger.debug("Starting up Provider Cache: #getName()# with configuration: #config.toString()#");
		
		// Validate the configuration
		validateConfiguration();

		// enabled cache
		instance.enabled = true;
		instance.reportingEnabled = true;
		instance.logger.info("Cache #getName()# started up successfully");
		
	}
	
	/**
    * shutdown the cache
    */
    void function shutdown() output="false" {
    	for( var memcachedClient in instance.memcachedClients ){
    		memcachedClient.shutDown( 5, instance.TimeUnitClass.SECONDS );
    		arrayDelete( instance.memcachedClients, memcachedClient );
    	}
    	instance.logger.info("Provider Cache: #getName()# has been shutdown.");
	}
	
	/*
	* Indicates if cache is ready for operation
	*/
	any function isEnabled() output="false" {
		return instance.enabled;
	} 

	/*
	* Indicates if cache is ready for reporting
	*/
	any function isReportingEnabled() output="false" {
		return instance.reportingEnabled;
	}
	
	/*
	* Get the cache statistics object as coldbox.system.cache.util.ICacheStats
	* @colddoc:generic coldbox.system.cache.util.ICacheStats
	*/
	any function getStats() output="false" {
		return new Stats( this );		
	}
	
	/**
    * clear the cache stats: 
    */
    void function clearStatistics() output="false" {
    	// Not implemented
	}
	
	/**
    * Returns the underlying cache engine represented by a Memcachedclient object
    * http://www.memcached.com/autodocs/memcached-java-client-1.1.5/index.html
    */
    any function getObjectStore() output="false" {
    	// This provider uses an external object store
    	return getMemcachedClient();
	}
	
	/**
    * get the cache's metadata report
    * @tested
    */
    any function getStoreMetadataReport() output="false" {	
		var md 		= {};
		var keys 	= getKeys();
		var item	= "";

		for( item in keys ){
			md[ item ] = getCachedObjectMetadata( item );
		}
		
		return md;
	}
	
	/**
	* Get a key lookup structure where cachebox can build the report on. Ex: [timeout=timeout,lastAccessTimeout=idleTimeout].  It is a way for the visualizer to construct the columns correctly on the reports
	* @tested
	*/
	any function getStoreMetadataKeyMap() output="false"{
		var keyMap = {
				LastAccessed = "LastAccessed",
				isExpired = "isExpired",
				timeout = "timeout",
				lastAccessTimeout = "lastAccessTimeout",
				hits = "hits",
				created = "createddate"
			};
		return keymap;
	}
	
	/**
    * get all the keys in this provider
    * @tested
    */
    any function getKeys() output="false" {
    	
    	local.allView = get( instance.designDocumentName );

    	if( isNull( local.allView ) ){
    		local.allView = [];
    		set( instance.designDocumentName, local.allView );
    	} else if( !isArray( local.allView ) ){
    		writeDump(var="BAD FORMAT",top=1);
    		writeDump(var=local.allView);
    		abort;
    	}

    	return local.allView;

	}

	void function appendCacheKey( objectKey ){

		var result = get( instance.designDocumentName );

		if( !isNull( result ) && isArray( result ) ) {
			if( isArray( arguments.objectKey ) ){
				arrayAppend( result, arguments.objectKey, true );
			} else if( !arrayFind( result, arguments.objectKey ) ){
				arrayAppend( result, arguments.objectKey );
				set( instance.designDocumentName, result );
			}
		} else {
			set( instance.designDocumentName, [ arguments.objectKey ] );
		}

	}
	
	/**
    * get an object's cached metadata
    * @tested
    */
    any function getCachedObjectMetadata(required any objectKey) output="false" {
    	// lower case the keys for case insensitivity
		if( !getConfiguration().caseSensitiveKeys )  arguments.objectKey = lcase( arguments.objectKey );
		
		// prepare stats return map
    	local.keyStats = {
			timeout = "",
			lastAccessed = "",
			timeExpires = "",
			isExpired = 0,
			isDirty = 0,
			isSimple = 1,
			createdDate = "",
			metadata = {},
			cas = "",
			dataAge = 0,
			// We don't track these two, but I need a dummy values
			// for the CacheBox item report.
			lastAccessTimeout = 0,
			hits = 0
		};

    	var local.object = getObjectStore().asyncGet( arguments.objectKey ).get();

    	// item is no longer in cache, or it's not a JSON doc.  No metastats for us
    	if( structKeyExists( local, "object" ) && isJSON( local.object ) ){
    		
    		// inflate our object from JSON
			local.inflatedElement = deserializeJSON( local.object );
			local.stats = duplicate( local.inflatedElement );

    		structAppend( local.keyStats, local.stats, true );
    		// key_exptime
    		if( structKeyExists( local.stats, "key_exptime" ) and isNumeric( local.stats[ "key_exptime" ] ) ){
    			local.keyStats.timeExpires = dateAdd("s", local.stats[ "key_exptime" ], dateConvert( "utc2Local", "January 1 1970 00:00" ) ); 
    		}
    		// key_last_modification_time
    		if( structKeyExists( local.stats, "key_last_modification_time" ) and isNumeric( local.stats[ "key_last_modification_time" ] ) ){
    			local.keyStats.lastAccessed = dateAdd("s", local.stats[ "key_last_modification_time" ], dateConvert( "utc2Local", "January 1 1970 00:00" ) ); 
    		}
    		// state
    		if( structKeyExists( local.stats, "key_vb_state" ) ){
    			local.keyStats.isExpired = ( local.stats[ "key_vb_state" ] eq "active" ? false : true ); 
    		}
    		// dirty
			if( structKeyExists( local.stats, "key_is_dirty" ) ){
    			local.keyStats.isDirty = local.stats[ "key_is_dirty" ]; 
    		}
    		// data_age
			if( structKeyExists( local.stats, "key_data_age" ) ){
    			local.keyStats.dataAge = local.stats[ "key_data_age" ]; 
    		}
    		// cas
			if( structKeyExists( local.stats, "key_cas" ) ){
    			local.keyStats.cas = local.stats[ "key_cas" ]; 
    		}

			// Simple values like 123 might appear to be JSON, but not a struct
			if(!isStruct(local.inflatedElement)) {
	    		return local.keyStats;
			}
					
			// createdDate
			if( structKeyExists( local.inflatedElement, "createdDate" ) ){
	   			local.keyStats.createdDate = local.inflatedElement.createdDate;
			}
			// timeout
			if( structKeyExists( local.inflatedElement, "timeout" ) ){
	   			local.keyStats.timeout = local.inflatedElement.timeout;
			}
			// metadata
			if( structKeyExists( local.inflatedElement, "metadata" ) ){
	   			local.keyStats.metadata = local.inflatedElement.metadata;
			}
			// isSimple
			if( structKeyExists( local.inflatedElement, "isSimple" ) ){
	   			local.keyStats.isSimple = local.inflatedElement.isSimple;
			}
    	}		
		
    	
    	return local.keyStats;
	}
	
	/**
    * get an item from cache, returns null if not found.
    * @tested
    */
    any function get(required any objectKey) output="false" {
    	return getQuiet(argumentCollection=arguments);
	}
	
	/**
    * get an item silently from cache, no stats advised: Stats not available on Memcached
    * @tested
    */
    any function getQuiet(required any objectKey) output="false" {
		// lower case the keys for case insensitivity
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );
		
		try {
    		// local.object will always come back as a string
    		g = getObjectStore().asyncGet( javacast( "string", arguments.objectKey ) );

    		var i = 0;

    		while( i < getConfiguration().timeoutExceptionThreshold && !g.isDone() ){
    			i++;
    			sleep( 1 );
    		}

    		if( !g.isDone() ){
    			g.cancel( javacast( "boolean", true ) );	
    		}  else {			
	    		local.object = g.get();	
    		}
			
			// item is no longer in cache, return null
			if( isNull( local.object ) ){
				return;
			}
			
			// return if not our JSON
			if( !isJSON( local.object ) ){
				return local.object;
			}
			
			// inflate our object from JSON

			local.inflatedElement = deserializeJSON( local.object );
			
			
			// Simple values like 123 might appear to be JSON, but not a struct
			if(!isStruct(local.inflatedElement)) {
				return local.object;
			}


			// Is simple or not?
			if( structKeyExists( local.inflatedElement, "isSimple" ) and local.inflatedElement.isSimple ){
				if( getConfiguration().updateStats ) updateObjectStats( arguments.objectKey, duplicate( local.inflatedElement ) );
				return local.inflatedElement.data;
			}

			// else we deserialize and return
			if( structKeyExists( local.inflatedElement, "data" ) ){
				local.inflatedElement.data = instance.converter.deserializeGeneric(binaryObject=local.inflatedElement.data);
				if( getConfiguration().updateStats ) updateObjectStats( arguments.objectKey, duplicate( local.inflatedElement ) );	
				return local.inflatedElement.data;
			}

			// who knows what this is?
			return local.object;
		}
		catch(any e) {
			
			if( isTimeoutException( e ) && getConfiguration().ignoreMemcachedTimeouts ) {
				// log it
				instance.logger.error( "Memcached timeout exception detected: #e.message# #e.detail#", e );
				// Return nothing as though it wasn't even found in the cache
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
	}

	any function getMulti( 
		required array objectKeys
	){
		var map = Javaloader.create( "java.util.ArrayList");
		map.addAll( arguments.objectKeys );

		if( structK )
		var f = getMemcachedClient().asyncGetBulk( objectKeys );
	
		var i = 0;
    	while( i < getConfiguration().timeoutExceptionThreshold && !g.isDone() ){
    			i++;
    			sleep( 1 );
    	}
    	if( !g.isDone() ) g.cancel( true );

    	var result = f.get();

    	writeDump(var=result,top=1);
    	abort;
	}
	
	/**
    * Not implemented by this cache
    */
    any function isExpired(required any objectKey) output="false" {
		return getCachedObjectMetadata( arguments.objectKey ).isExpired;
	}
	 
	/**
    * check if object in cache
    * @tested
    */
    any function lookup(required any objectKey) output="false" {
    	return ( isNull( get( objectKey ) ) ? false : true );
	}
	
	/**
    * check if object in cache with no stats: Stats not available on Memcached
    * @tested
    */
    any function lookupQuiet(required any objectKey) output="false" {
		// not possible yet on Memcached
		return lookup( arguments.objectKey );
	}
	
	/**
    * set an object in cache and returns an object future if possible
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
    any function set(
    	required any objectKey,
		required any object,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, // Not in use for this provider
		any extra={}
	) output="false" {
		
		var future = setQuiet(argumentCollection=arguments);
		
		//ColdBox events
		var iData = { 
			"cache"				= this,
			"cacheObject"			= arguments.object,
			"cacheObjectKey" 		= arguments.objectKey,
			"cacheObjectTimeout" 	= arguments.timeout,
			"cacheObjectLastAccessTimeout" = arguments.lastAccessTimeout,
			"memcachedFuture" 	= future
		};

		if( arguments.objectKey != instance.designDocumentName ) appendCacheKey( arguments.objectKey );

		getEventManager().processState( state="afterCacheElementInsert", interceptData=iData, async=true );
		
		return future;
	}

	void function updateObjectStats( required any objectKey, required any cacheObject ){
		
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );
		if( !structKeyExists( cacheObject, "accessCount" ) ) cacheObject[ "accessCount" ] = 0;

		cacheObject[ "lastAccessed" ] = dateformat( now(), "mm/dd/yyyy") & " " & timeformat( now(), "full" );
		cacheObject[ "accessCount" ]++;

		// Do we need to serialize incoming obj
		if( !cacheObject.isSimple && !isSimpleValue( cacheObject.data ) ){
			cacheObject.data = instance.converter.serializeGeneric( cacheObject.data );
		}

		persistToCache( arguments.objectKey, cacheObject , true );
	}	
	
	/**
    * set an object in cache with no advising to events, returns a memcached future if possible
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
    any function setQuiet(
	    required any objectKey,
		required any object,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, //Not in use for this provider
		any extra={}
	) output="false" {
		
		// check case-sensitivity settings
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );
		
		return persistToCache( arguments.objectKey, formatCacheObject( argumentCollection=arguments ) );
	}	


	/**
    * Set multiple items in to the cache
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
	any function setMulti( 
		required struct mapping,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, // Not in use for this provider
		any extra={}
	) output="false" {
		//SpyMemcached doesn't have a bulk write method, so we have to send each one individually
		for( var key in arguments.mapping ){
			var f = setQuiet( key, arguments.mapping[ key ], arguments.timeout, arguments.lastAccessTimeout, arguments.extra );
			var i = 0;
			while( i < getConfiguration().timeoutExceptionThreshold && !f.isDone() ){
				i++;
				sleep( 1 );
			}
			//if there was an error cancel out
			if( !f.isDone() ){
				f.cancel( javacast( "boolean", true ) );
				//retry but don't confirm
				if( !f.isCancelled() ) setQuiet( key, arguments.mapping[ key ], arguments.timeout, arguments.lastAccessTimeout, arguments.extra );
			}
		}
		appendCacheKey( structKeyArray( arguments.mapping ) );
	}

	any function formatCacheObject( 
		required any object,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, //Not in use for this provider
		any extra={}
	) output="false" {
		// create storage element
		var sElement = {
			"createdDate" = dateformat( now(), "mm/dd/yyyy") & " " & timeformat( now(), "full" ),
			"timeout" = arguments.timeout,
			"metadata" = ( !isNull(arguments.extra) && structKeyExists( arguments.extra, "metadata" ) ? arguments.extra.metadata : {} ),
			"isSimple" = isSimpleValue( arguments.object ),
			"data" = arguments.object,
			"accessCount" = 0
		};

		// Do we need to serialize incoming obj
		if( !sElement.isSimple ){
			sElement.data = instance.converter.serializeGeneric( sElement.data );
		}

		return sElement;
	}

	any function persistToCache( 
		required any objectKey,
		required any cacheObject,
		boolean replaceItem=false
		any extra
	) output="false" {
		
		// Serialize element to JSON
		var sElement = serializeJSON( arguments.cacheObject );

    	try {
    		
			// You can pass in a net.spy.memcached.transcoders.Transcoder to override the default
			if( structKeyExists( arguments, 'extra' ) && structKeyExists( arguments.extra, 'transcoder' ) ){
				if( !replaceItem ){
					var future = getMemcachedClient()
						.set( javaCast( "string", arguments.objectKey ), javaCast( "int", arguments.cacheObject.timeout*60 ), sElement, extra.transcoder );	
				} else {
					
					var future = getMemcachedClient()
					.replace( javaCast( "string", arguments.objectKey ), javaCast( "int", arguments.cacheObject.timeout*60 ), sElement, extra.transcoder );
				}
			}
			else {
				if( !replaceItem ){
					var future = getMemcachedClient()
					.set( javaCast( "string", arguments.objectKey ), javaCast( "int", arguments.cacheObject.timeout*60 ), sElement );
				} else {
					var future = getMemcachedClient()
					.replace( javaCast( "string", arguments.objectKey ), javaCast( "int", arguments.cacheObject.timeout*60 ), sElement );
				}
			}
		
		}
		catch(any e) {
			
			if( isTimeoutException( e ) && getConfiguration().ignoreMemcachedTimeouts) {
				// log it
				instance.logger.error( "Memcached timeout exception detected: #e.message# #e.detail#", e );
				// return nothing
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
		
		return future;
	}
		
	/**
    * get cache size
    * @tested
    */
    any function getSize() output="false" {
		return getStats().getObjectCount();
	}
	
	/**
    * Not implemented by this cache
    * @tested
    */
    void function reap() output="false" {
		// Not implemented by this provider
	}
	
	/**
    * clear all elements from cache
    * @tested
    */
    void function clearAll() output="false" {
		
		// If flush is not enabled for this bucket, no error will be thrown.  The call will simply return and nothing will happen.
		// Be very careful calling this.  It is an intensive asynch operation and the cache won't receive any new items until the flush
		// is finished which might take a few minutes.
		var future = getObjectStore().flush();		
				 
		var iData = {
			cache			= this,
			memcachedFuture = future
		};
		
		// notify listeners		
		getEventManager().processState("afterCacheClearAll",iData);
	}
	
	/**
    * clear an element from cache and returns the memcached java future
    * @tested
    */
    any function clear(required any objectKey) output="false" {
		// lower case the keys for case insensitivity
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );
		
		// Delete from memcached
		var future = getObjectStore().delete( arguments.objectKey );
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObjectKey 		= arguments.objectKey,
			memcachedFuture		= future
		};		
		getEventManager().processState( state="afterCacheElementRemoved", interceptData=iData, async=true );
		
		return future;
	}
	
	/**
    * Clear with no advising to events and returns with the memcached java future
    * @tested
    */
    any function clearQuiet(required any objectKey) output="false" {
		// normal clear, not implemented by Memcached
		return clear( arguments.objectKey );
	}
	
	/**
	* Clear by key snippet
	*/
	void function clearByKeySnippet(required keySnippet, regex=false, async=false) output="false" {

		var threadName = "clearByKeySnippet_#replace(instance.uuidHelper.randomUUID(),"-","","all")#";
		
		// Async? IF so, do checks
		if( arguments.async AND NOT instance.utility.inThread() ){
			thread name="#threadName#"{
				instance.elementCleaner.clearByKeySnippet(arguments.keySnippet,arguments.regex);
			}
		}
		else{
			instance.elementCleaner.clearByKeySnippet(arguments.keySnippet,arguments.regex);
		}
		
	}
	
	/**
    * Expiration not implemented by memcached so clears are issued
    * @tested
    */
    void function expireAll() output="false"{ 
		clearAll();
	}
	
	/**
    * Expiration not implemented by memcached so clear is issued
    * @tested
    */
    void function expireObject(required any objectKey) output="false"{
		clear( arguments.objectKey );
	}

	/************************************** PRIVATE *********************************************/
	
	/**
	* Validate the incoming configuration and make necessary defaults
	**/
	private void function validateConfiguration() output="false"{
		var cacheConfig = getConfiguration();
		var key			= "";
		
		// Validate configuration values, if they don't exist, then default them to DEFAULTS
		for(key in instance.DEFAULTS){
			if( NOT structKeyExists( cacheConfig, key) OR ( isSimpleValue( cacheConfig[ key ] ) AND NOT len( cacheConfig[ key ] ) ) ){
				cacheConfig[ key ] = instance.DEFAULTS[ key ];
			}
			
			// Force servers to be an array even if there's only one and ensure proper URI format
			if( key == 'servers' ) {
				cacheConfig[ key ] = formatServers( cacheConfig[ key ] );
			}
			
		}

		setConfiguration( cacheConfig );
	}
	
	/**
    * Format the incoming simple couchbas server URL location strings into our format
    */
    private any function formatServers(required servers) {
    	var i = 0;

    	var formattedServers = createObject( "java", "java.util.ArrayList" );

		if( !isArray( servers ) ){
			servers = listToArray( servers );
		}

		for( var configServer in servers  ){
			var address = listToArray( configServer, ":" );
			if( !arraylen( address ) > 1 ) throw( "MemcachedProviderException", "The address provided ( #server# ) does not contain an address/port configuration" );
			var socketAddr = createObject("java", "java.net.InetSocketAddress" ).init( address[ 1 ], address[ 2 ] );
			formattedServers.add( socketAddr );
		}
		
		return formattedServers;
	}
	
	private boolean function isTimeoutException(required any exception){
    	return (exception.type == 'net.spy.memcached.OperationTimeoutException' || exception.message == 'Exception waiting for value' || exception.message == 'Interrupted waiting for value');
	}
	
	/**
    * Deal with errors that came back from the cluster
    * rowErrors is an array of com.memcached.client.protocol.views.RowError
    */
    private any function handleRowErrors(message, rowErrors) {
    	local.detail = '';
    	for(local.error in arguments.rowErrors) {
    		local.detail &= local.error.getFrom();
    		local.detail &= local.error.getReason();
    	}
    	
    	// It appears that there is still a useful result even if errors were returned so
    	// we'll just log it and not interrupt the request by throwing.  
    	instance.logger.warn(arguments.message, local.detail);
    	//Throw(message=arguments.message, detail=local.detail);
    	
    	return this;
    }

}
