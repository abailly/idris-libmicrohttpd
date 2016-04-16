module Status_codes

%access export

HTTP_ok : Int
HTTP_ok = 200

HTTP_bad_request : Int
HTTP_bad_request = 400

HTTP_forbidden : Int
HTTP_forbidden = 403

HTTP_not_found : Int
HTTP_not_found = 404

HTTP_not_acceptable : Int
HTTP_not_acceptable = 406

HTTP_internal_server_error : Int
HTTP_internal_server_error = 500

HTTP_service_unavailable : Int
HTTP_service_unavailable = 503
