enum AdherenceFailureKind {
  denied,
  unauthorized,
  invalidRange,
  network,
  unavailable,
  invalidResponse,
}

class AdherenceFailure implements Exception {
  const AdherenceFailure(this.kind);

  final AdherenceFailureKind kind;
}
