// ============================================================================
// LocalServerConfig
// ============================================================================
//
// Configuration for the local HTTP server. Loopback-only binding by default
// with configurable port for testing.
//
// See M7-05: Server Foundation

class LocalServerConfig {
  const LocalServerConfig({
    this.host = '127.0.0.1',
    this.port = 3727,
    this.enabled = false,
  });

  /// Server binds to loopback only (IPv4). M7-06 may add IPv6 ::1 support.
  final String host;

  /// Port number. Use 0 for OS-assigned port in tests.
  final int port;

  /// Whether the server should auto-start. M7-05 does not integrate with app
  /// startup; this is for future M7-06/M7-07 integration.
  final bool enabled;

  /// Validate configuration constraints.
  bool get isValid {
    if (port < 0 || port > 65535) return false;
    if (host != '127.0.0.1' && host != '::1' && host != 'localhost') {
      return false;
    }
    return true;
  }

  /// Create test configuration with OS-assigned port.
  LocalServerConfig forTest() {
    return LocalServerConfig(host: host, port: 0, enabled: enabled);
  }

  LocalServerConfig copyWith({String? host, int? port, bool? enabled}) {
    return LocalServerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      enabled: enabled ?? this.enabled,
    );
  }
}
