// Failure modes for MockAIProvider — kept top-level so they're reachable anywhere.
enum FailureMode {
  success,
  networkError,
  timeout,
  invalidRequest,
}
