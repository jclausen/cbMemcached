/*******************************************************************************
* Integration Tests for Coldbox Custom Caches
*******************************************************************************/
component extends="coldbox.system.testing.BaseTestCase" appMapping="/" accessors=true{
	property name="cachebox" inject="cachebox";
	property name="wirebox" inject="wirebox";
	this.loadColdbox=true;
	
	/*********************************** LIFE CYCLE Methods ***********************************/

	function beforeAll(){
		super.beforeAll();
		// setup a framework request
		setup();
		expect( application ).toHaveKey( "wirebox", "Wirebox is required to perform these integration tests" );
		application.wirebox.autowire( this );
		expect( isNull( getCachebox() ) ).toBeFalse( "Autowiring failed. Could not continue" );
		VARIABLES.Cache = Cachebox.getCache( "integration-tests" );
		VARIABLES.Cache.clearAll();

	}

	function afterAll(){
		// do your own stuff here
		super.afterAll();

	}

	/*********************************** BDD SUITES ***********************************/
	
	function run(){

		describe( "Tests basic functionality of the Custom Cache within the framework context", function(){

			it("Tests basic CRUD functionality of the cache", function(){
				expect( VARIABLES ).toHaveKey( "Cache" );
				expect( VARIABLES.Cache.get( "testKey" ) ).toBeNull("There are leftover values in the cache.  Tests could not continue");

				// null value
				var r = cache.get( 'invalid' );
				assertTrue( isNull( r ) );
				

				var testVal = {name="luis", age=32};
				VARIABLES.Cache.set( 'unitTestKey', testVal );
				
				var results = VARIABLES.Cache.get( "unitTestKey" );
				
				expect( !isNull( results ) ).toBeTrue();
				expect( isStruct( results ) ).toBeTrue();
				expect( (results.name=="luis") ).toBeTrue();
				
				VARIABLES.Cache.set( 'anotherKey', 'Hello Redis');
				var results = VARIABLES.Cache.get( "anotherKey" );
				expect( !isNull( results )).toBeTrue("The results returned from the cache were unexpectedly null." );
				expect( results ).toBe('Hello Redis' );

				//Tests setMulti
				var multi = {}
				for( var i=1; i <= 100; i++ ){
					multi[ "foo#i#" ]="bar#i#"
				}
				VARIABLES.Cache.setMulti( multi );
				sleep( 2 );
				for( var key in multi ){
					expect( VARIABLES.Cache.get( key ) ).toBe( multi[ key ] );
				}

				//Tests getMulti
				var multiGet = VARIABLES.Cache.getMulti( structKeyArray( multi ) );
				expect( multiGet ).toBeStruct();
				expect( arrayLen( structKeyArray( multiGet ) ) ).toBe( arrayLen( structKeyArray( multi ) ) );
				for( var key in multiGet ){
					expect( multiGet[ key ] ).toBe( multi[ key ] );
				}



			});
		
		});

	}

}
