/**
*********************************************************************************
* Your Copyright
********************************************************************************
*/
component{

	// Module Properties
	this.title 				= "cbMemcached";
	this.author 			= "Jon Clausen";
	this.webURL 			= "";
	this.description 		= "Cachebox Memcached Provider Module for Coldbox";
	this.version			= "@build.version@+@build.number@";
	// If true, looks for views in the parent first, if not found, then in the module. Else vice-versa
	this.viewParentLookup 	= true;
	// If true, looks for layouts in the parent first, if not found, then in module. Else vice-versa
	this.layoutParentLookup = true;
	// Module Entry Point
	this.entryPoint			= "cbmemcached";
	// Model Namespace
	this.modelNamespace		= "cbmemcached";
	// CF Mapping
	this.cfmapping			= "cbmemcached";
	// Auto-map models
	this.autoMapModels		= true;
	// Module Dependencies That Must Be Loaded First, use internal names or aliases
	this.dependencies		= [ 'cbjavaloader' ];

	/**
	* Configure module
	*/
	function configure(){
	}

	/**
	* Fired when the module is registered and activated.
	*/
	function onLoad(){
		var jLoader = Wirebox.getInstance("Loader@cbjavaloader");
		jLoader.appendPaths( modulePath & '/lib/' );
	}

	/**
	* Fired when the module is unregistered and unloaded
	*/
	function onUnload(){
		
	}

}
