import 'dart:io';

final class AgentEvaluationSupervisorConnection {
  AgentEvaluationSupervisorConnection._(this._socket);

  final Socket _socket;
  var _closingNormally = false;

  static Future<AgentEvaluationSupervisorConnection> connect(
    Map<String, String> environment,
  ) async {
    final port = int.tryParse(environment['AGENT_EVAL_SUPERVISOR_PORT'] ?? '');
    final token = (environment['AGENT_EVAL_SUPERVISOR_TOKEN'] ?? '').trim();
    if (port == null || port <= 0 || token.isEmpty) {
      throw StateError('release supervisor is missing');
    }
    // Ownership is transferred to the returned connection, which holds the
    // socket for the process lifetime and closes it on every normal exit.
    // ignore: close_sinks
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.writeln(token);
    final result = AgentEvaluationSupervisorConnection._(socket);
    socket.listen(
      (_) {},
      onError: (_) {
        if (!result._closingNormally) exit(125);
      },
      onDone: () {
        if (!result._closingNormally) exit(125);
      },
      cancelOnError: true,
    );
    return result;
  }

  Future<void> closeNormally() async {
    _closingNormally = true;
    await _socket.close();
  }
}
