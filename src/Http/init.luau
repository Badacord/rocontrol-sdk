--!strict
-- Re-export surface for the HTTP layer.
return {
	HttpClient = require(script.HttpClient),
	Routes = require(script.Routes),
	Retry = require(script.Retry),
	CircuitBreaker = require(script.CircuitBreaker),
	ResponseClassifier = require(script.ResponseClassifier),
}
