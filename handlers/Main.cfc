/**
* My Event Handler Hint
*/
component accessors=true{
	property name="cachebox" inject="cachebox";

	// Index
	any function index( event, rc, prc ){

		var cache = getCachebox().getCache("template");
		
		var bar = ["bar"];

		var future = cache.set( "foo", bar );

		var foo2 = cache.get( "foo" );


		arrayAppend( foo2, "bar2" );

		cache.set( "foo", foo2 );

		writeDump(var=cache.get("foo") );
		writeDump(var=cache.get("foo") );
		writeDump(var=cache.get("foo") );
		abort;

		//writeDump(var=getCachebox().getCache("template").getMemcachedClient(),top=1);
		abort;
		event.setView( "main/index" );
	}

	// Run on first init
	any function onAppInit( event, rc, prc ){

	}

}