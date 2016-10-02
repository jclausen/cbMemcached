component{

	// Configure ColdBox Application
	function configure(){

		// coldbox directives
		coldbox = {
			//Application Setup
			appName 				= "Development Shell",

			//Development Settings
			reinitPassword			= "",
			handlersIndexAutoReload = true,

			//Implicit Events
			defaultEvent			= "main.index",
			requestStartHandler		= "",
			requestEndHandler		= "",
			applicationStartHandler = "main.onAppInit",
			applicationEndHandler	= "",
			sessionStartHandler 	= "",
			sessionEndHandler		= "",
			missingTemplateHandler	= "",

			//Extension Points
			ApplicationHelper 				= "",
			coldboxExtensionsLocation 	= "",
			modulesExternalLocation		= [],
			pluginsExternalLocation 	= "",
			viewsExternalLocation		= "",
			layoutsExternalLocation 	= "",
			handlersExternalLocation  	= "",
			requestContextDecorator 	= "",

			//Error/Exception Handling
			exceptionHandler		= "",
			onInvalidEvent			= "",
			customErrorTemplate		= "/coldbox/system/includes/BugReport.cfm",

			//Application Aspects
			handlerCaching 			= false,
			eventCaching			= false,
			proxyReturnCollection 	= false
		};

		// custom settings
		settings = {
		};

		// Activate WireBox
		wirebox = { enabled = true, singletonReload=true };

		// Module Directives
		modules = {
			//Turn to false in production, on for dev
			autoReload = false
		};

		//LogBox DSL
		logBox = {
			// Define Appenders
			appenders = {
				files={class="coldbox.system.logging.appenders.RollingFileAppender",
					properties = {
						filename = "javaloader", filePath="/#appMapping#/logs"
					}
				}
			},
			// Root Logger
			root = { levelmax="DEBUG", appenders="*" },
			// Implicit Level Categories
			info = [ "coldbox.system" ]
		};

		cacheBox = {
	        // LogBox Configuration file
	        logBoxConfig = "coldbox.system.cache.config.LogBox", 
	        
	        // Scope registration, automatically register the cachebox factory instance on any CF scope
	        // By default it registers itself on application scope
	        scopeRegistration = {
	            enabled = true,
	            scope   = "application", // valid CF scope
	            key     = "cacheBox"
	        },
	        
	        // The defaultCache has an implicit name of "default" which is a reserved cache name
	        // It also has a default provider of cachebox which cannot be changed.
	        // All timeouts are in minutes
	        // Please note that each object store could have more configuration properties
	        defaultCache = {
	            objectDefaultTimeout = 120,
	            objectDefaultLastAccessTimeout = 30,
	            useLastAccessTimeouts = true,
	            reapFrequency = 2,
	            freeMemoryPercentageThreshold = 0,
	            evictionPolicy = "LRU",
	            evictCount = 1,
	            maxObjects = 300,
	            // Our default store is the concurrent soft reference
	            objectStore = "ConcurrentSoftReferenceStore",
	            // This switches the internal provider from normal cacheBox to coldbox enabled cachebox
	            coldboxEnabled = false
	        },
	        
	        // Register local in-memory caches here ( Distributed caches appended below )
	        caches = {
	        	"template" :
				 {
					provider : 'modules.cbmemcached.models.MemcachedColdboxProvider'
				    ,properties : {}
				},
				"integration-tests" :
				 {
					provider : 'modules.cbmemcached.models.MemcachedColdboxProvider'
				    ,properties : {}
				}
	        },        
	        // Register all event listeners here, they are created in the specified order
	        listeners = []      
	    };

		//Register interceptors as an array, we need order
		interceptors = [
			//SES
			{class="coldbox.system.interceptors.SES",
			 properties={}
			}
		];

	}

}