export 'app_llm_client_contract.dart';
export 'app_llm_client_gateway.dart';
export 'app_llm_client_types.dart';
export 'app_llm_logging_middleware.dart';
export 'app_llm_provider_adapters.dart';
export 'app_llm_response_cache.dart';
export 'app_llm_token_usage.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';

import 'app_llm_client_stub.dart' if (dart.library.io) 'app_llm_client_io.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_gateway.dart';
import 'app_llm_logging_middleware.dart';
import 'app_llm_response_cache.dart';

AppLlmClient createDefaultAppLlmClient() => createAppLlmClient();

AppLlmClient createCachedAppLlmClient() =>
    AppLlmResponseCache(delegate: createAppLlmClient());

AppLlmClient createResilientAppLlmClient({AppLlmClient? delegate}) =>
    AppLlmClientGateway(delegate: delegate ?? createCachedAppLlmClient());

AppLlmClient createLoggedAppLlmClient({AppEventLog? eventLog}) =>
    AppLlmLoggingMiddleware(
      delegate: createResilientAppLlmClient(),
      eventLog: eventLog,
    );
