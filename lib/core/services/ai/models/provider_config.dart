import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_config.dart';
import 'model_tier.dart';

part 'provider_config.freezed.dart';
part 'provider_config.g.dart';

/// 供应商配置
/// 存储每个 AI 供应商的 API 凭证和设置
@freezed
class ProviderConfig with _$ProviderConfig {
  const ProviderConfig._();

  const factory ProviderConfig({
    required String id,
    required AIProviderType type,
    required String name,
    String? apiKey, // 加密存储
    String? apiEndpoint, // 自定义端点
    @Default({}) Map<String, String> headers, // 自定义请求头
    @Default(30) int timeoutSeconds,
    @Default(3) int maxRetries,
    @Default(true) bool isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ProviderConfig;

  factory ProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$ProviderConfigFromJson(json);

  /// 获取完整的 API 端点
  String get effectiveEndpoint {
    if (apiEndpoint != null && apiEndpoint!.isNotEmpty) {
      return apiEndpoint!;
    }
    return type.defaultEndpoint;
  }

  /// 验证端点 URL 安全性（防止 SSRF 攻击）
  /// 返回 null 表示验证通过，否则返回错误信息
  static String? validateEndpoint(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '无效的 URL 格式';
    }

    // 只允许 http/https 协议
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '仅支持 http/https 协议';
    }

    final host = uri.host.toLowerCase();

    // 屏蔽链路本地地址（云元数据等）
    if (host == '169.254.169.254' || host.startsWith('169.254.')) {
      return '不允许访问链路本地地址';
    }

    // 对于 https，屏蔽 localhost 和回环地址
    // 对于 http，允许 localhost（Ollama 本地服务）
    if (uri.scheme == 'https') {
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return 'HTTPS 不允许连接本地地址';
      }
    }

    // 屏蔽 RFC 1918 私有 IP（仅对公网端点检查，允许 http 的私有 IP 用于本地服务）
    if (uri.scheme == 'https') {
      final ipRegExp = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$');
      final match = ipRegExp.firstMatch(host);
      if (match != null) {
        final octets = [
          int.tryParse(match.group(1)!) ?? 0,
          int.tryParse(match.group(2)!) ?? 0,
          int.tryParse(match.group(3)!) ?? 0,
          int.tryParse(match.group(4)!) ?? 0,
        ];
        // 10.0.0.0/8
        if (octets[0] == 10) {
          return '不允许访问私有网络地址';
        }
        // 172.16.0.0/12
        if (octets[0] == 172 &&
            octets[1] >= 16 &&
            octets[1] <= 31) {
          return '不允许访问私有网络地址';
        }
        // 192.168.0.0/16
        if (octets[0] == 192 && octets[1] == 168) {
          return '不允许访问私有网络地址';
        }
      }
    }

    return null; // 验证通过
  }

  /// 验证当前端点是否安全
  String? get endpointValidationError =>
      validateEndpoint(effectiveEndpoint);
}

/// 连接测试结果
class ConnectionTestResult {
  final bool success;
  final String? errorMessage;

  const ConnectionTestResult({
    required this.success,
    this.errorMessage,
  });

  static ConnectionTestResult ok() =>
      const ConnectionTestResult(success: true);

  static ConnectionTestResult fail(String message) =>
      ConnectionTestResult(success: false, errorMessage: message);
}

/// 功能-模型映射配置
@freezed
class FunctionMapping with _$FunctionMapping {
  const FunctionMapping._();

  const factory FunctionMapping({
    required String functionKey,  // 使用 key 而非枚举
    String? overrideModelId,      // 覆盖默认层级，使用指定模型
    @Default(false) bool useOverride, // 是否使用覆盖
  }) = _FunctionMapping;

  factory FunctionMapping.fromJson(Map<String, dynamic> json) =>
      _$FunctionMappingFromJson(json);

  /// 获取对应的 AIFunction
  AIFunction? get function => AIFunction.fromKey(functionKey);

  /// 默认映射
  static List<FunctionMapping> defaults() =>
      AIFunction.values.map((f) => FunctionMapping(functionKey: f.key)).toList();
}
