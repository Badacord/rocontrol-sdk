--!strict
-- The single point where the SDK touches HttpService. Everything above this layer
-- works against the `HttpAdapter` interface, so tests inject a fake that returns
-- canned responses without any network access.

export type HttpRequest = {
	method: string,
	url: string,
	headers: { [string]: any },
	body: string?,
}

export type HttpResponse = {
	success: boolean,
	statusCode: number,
	statusMessage: string,
	headers: { [string]: any },
	body: string,
}

export type HttpAdapter = {
	-- Performs a blocking request. Must not raise on HTTP error codes; only raise
	-- (return success=false via pcall) on transport failure.
	request: (self: HttpAdapter, req: HttpRequest) -> HttpResponse,
	-- JSON helpers kept on the adapter so the encoder is consistent and fakeable.
	encode: (self: HttpAdapter, value: any) -> string,
	decode: (self: HttpAdapter, text: string) -> any,
}

local HttpServiceAdapter = {}
HttpServiceAdapter.__index = HttpServiceAdapter

function HttpServiceAdapter.new(): HttpAdapter
	local HttpService = game:GetService("HttpService")
	local self = setmetatable({ _http = HttpService }, HttpServiceAdapter)
	return (self :: any) :: HttpAdapter
end

function HttpServiceAdapter.request(self: any, req: HttpRequest): HttpResponse
	local ok, result = pcall(function()
		return self._http:RequestAsync({
			Url = req.url,
			Method = req.method,
			Headers = req.headers,
			Body = req.body,
		})
	end)

	if not ok then
		-- Transport failure (DNS, http disabled, dropped connection). Surface a
		-- synthetic 0 so the classifier treats it as a retryable transport error.
		return {
			success = false,
			statusCode = 0,
			statusMessage = tostring(result),
			headers = {},
			body = "",
		}
	end

	return {
		success = result.Success,
		statusCode = result.StatusCode,
		statusMessage = result.StatusMessage,
		headers = result.Headers,
		body = result.Body,
	}
end

function HttpServiceAdapter.encode(self: any, value: any): string
	return self._http:JSONEncode(value)
end

function HttpServiceAdapter.decode(self: any, text: string): any
	if text == nil or text == "" then
		return nil
	end
	local ok, decoded = pcall(function()
		return self._http:JSONDecode(text)
	end)
	if ok then
		return decoded
	end
	return nil
end

return HttpServiceAdapter
