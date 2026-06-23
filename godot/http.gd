class_name HTTP
extends Node

class Response:
	var _result: HTTPRequest.Result

	func success() -> bool:
		return self is ResponseSuccess

	func fail() -> bool:
		return self is ResponseFail

	static func from_error(error: Error) -> Response:
		return ResponseFail.new(error)

	static func from_array(a: Array) -> Response:
		var result: HTTPRequest.Result = a[0]
		var h: Response
		
		if result != HTTPRequest.Result.RESULT_SUCCESS:
			h = Response.from_error(OK)
			h._result = result
		else:
			h = ResponseSuccess._from_array(result, a)
		
		return h

class ResponseFail extends Response:
	var error: Error
	
	func _init(_error: Error) -> void:
		self.error = _error
	
class ResponseSuccess extends Response:
	
	var status: int
	var headers: PackedStringArray
	var body: PackedByteArray
	
	func status_ok() -> bool:
		return status >= 200 and status < 300

	func status_err() -> bool:
		return status >= 400 and status < 600

	func body_as_string() -> String:
		return body.get_string_from_utf8()

	func body_as_json() -> Variant:
		return JSON.parse_string(body_as_string())
	
	func headers_dict() -> Dictionary[String, String]:
		var dict: Dictionary[String, String] = {}
		for h: String in self.headers:
			var split: PackedStringArray = h.split(":", true, 1)
			dict[split[0].to_lower()] = split[1].strip_edges(true, false)

		return dict
	
	static func _from_array(result: HTTPRequest.Result, a: Array) -> Response:
		var _status: int = a[1]
		var _headers: PackedStringArray = a[2]
		var _body: PackedByteArray = a[3]
		
		var h: Response = ResponseSuccess.new()
		
		h._result = result
		h.status = _status
		h.headers = _headers
		h.body = _body
		
		return h

var _default_headers: PackedStringArray

func _init(default_headers: PackedStringArray = []) -> void:
	self._default_headers = default_headers

func request(url: String, custom_headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, request_data: String = "") -> Response:
	var http: HTTPRequest = HTTPRequest.new()
	self.add_child(http)
	
	if _default_headers and custom_headers:
		custom_headers = PackedStringArray(custom_headers)
		custom_headers.append_array(_default_headers)
	
	var err: Error = http.request(url, custom_headers, method, request_data)
	
	if err:
		http.queue_free()
		return ResponseFail.new(err)
	
	var resp: Array = await http.request_completed
	
	http.queue_free()
	return Response.from_array(resp)

func request_json_or_null(url: String, custom_headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, request_data: String = "") -> Variant:
	var resp: HTTP.Response = await self.request(url, custom_headers, method, request_data)
	
	if resp is ResponseFail:
		push_error("Failed to make a HTTP request: ", resp._error)
		return null
	
	var success: ResponseSuccess = resp
	
	if success.status_err():
		push_error("Error making HTTP request to ", url, ": ", success.status, " ", success.body_as_string())
		return null
	
	return success.body_as_json()
