component {
  /*
    Copyright (c) 2016-2017, Sean Corfield

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
  */

  // expose cookie scope in request
  function wrap_cookies( handler ) {
    return function( req ) {
      if ( !req.keyExists( "cookies" ) ) req.cookies = { };
      req.cookies.append( cookie );
      var resp = handler( req );
      if ( resp.keyExists( "cookies" ) ) {
        // for now -- we should probably remove deleted items
        // should also be smarter about options on cookies
        cookie.append( resp.cookies );
      }
      return resp;
    };
  }

  // copy url (query string) and form to params
  function wrap_params( handler ) {
    return function( req ) {
      if ( !req.keyExists( "params" ) ) req.params = { };
      if ( !req.keyExists( "query_params" ) ) {
        req.query_params = { };
        req.query_params.append( url );
      }
      if ( !req.keyExists( "form_params" ) ) {
        req.form_params = { };
        req.form_params.append( form );
      }
      req.params.append( url );
      req.params.append( form );
      return handler( req );
    };
  }

  // expose session scope in request
  function wrap_session( handler ) {
    return function( req ) {
      if ( !req.keyExists( "session" ) ) req.session = { };
      req.session.append( session );
      var resp = handler( req );
      if ( resp.keyExists( "session" ) ) {
        // for now -- we should probably remove deleted items
        session.append( resp.session );
      }
      return resp;
    };
  }

  // decode JSON body to params
  function wrap_json_params( handler ) {
    return function( req ) {
      var body = getHTTPRequestData().content;
      if ( isBinary( body ) ) body = charsetEncode( body, "utf-8" );
      if ( len( body ) ) {
        switch ( listFirst( req.content_type, ";" ) ) {
        case "application/json":
        case "text/json":
          var params = deserializeJSON( body );
          req.json_params = params;
          if ( !req.keyExists( "params" ) ) req.params = { };
          req.params.append( params );
          break;
        case "application/x-www-form-urlencoded":
          var pairs = listToArray( body, "&" );
          var params = { };
          for ( var pair in pairs ) {
            var parts = listToArray( pair, "=", true ); // handle blank values
            params[ parts[ 1 ] ] = urlDecode( parts[ 2 ] );
          }
          req.json_params = params;
          if ( !req.keyExists( "params" ) ) req.params = { };
          req.params.append( params );
          break;
        default:
          // ignore!
          break;
        }
      }
      return handler( req );
    };
  }

  // encode non-string body to JSON
  function wrap_json_response( handler ) {
    return function( req ) {
      var resp = handler( req );
      var r = new ring.util.response();
      if ( r.is_response( resp ) && !isSimpleValue( resp.body ) ) {
        resp.body = serializeJSON( resp.body );
        resp = r.content_type( resp, "application/json; charset=utf-8" );
      }
      return resp;
    };
  }

  // CORS support (OPTIONS, Access Control)
  function wrap_cors( handler ) {
    return function( req ) {
      // TODO!
      return handler( req );
    };
  }

  // handle exceptions gracefully
  function wrap_exception( handler ) {
    return function( req ) {
      try {
        return handler( req );
      } catch ( any e ) {
        var r = new ring.util.response();
        var stdout = createObject( "java", "java.lang.System" ).out;
        stdout.println( "Exception: #e.message# : #e.detail# in #req.uri#" );
        var resp = r.response( e.message );
        return r.status( resp, 400 );
      }
    };
  }

  // CFML-specific convenience to make stacking middleware easier
  function stack( handler, middleware ) {
    for ( var m in middleware ) {
      handler = m( handler );
    }
    return handler;
  }

  // CFML-specific convenience for default middleware stacking
  function default_stack( handler ) {
    var v = ( variables.keyExists( "stack" ) && variables.keyExists( "default_stack" ) )
      ? variables : new ring.middleware();
    return v.stack(
      handler,
      [
        wrap_json_response,
        wrap_json_params,
        wrap_params,
        wrap_session,
        wrap_cookies,
        wrap_cors,
        wrap_exception
      ]
    );
  }

}
