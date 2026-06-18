import 'provider_config.dart';

class AppConfig {
  const AppConfig({
    required this.dailyWorkHours,
    required this.dailySalary,
    required this.industry,
    required this.appFont,
    required this.fontScale,
    required this.autoStart,
    required this.showUpdates,
    required this.showDesktopWidget,
    required this.memorySearchLimit,
    required this.apiLogEnabled,
    required this.providers,
    required this.defaultModels,
    required this.hotkeys,
  });

  final double dailyWorkHours;
  final double dailySalary;
  final String industry;
  final String appFont;
  final double fontScale;
  final bool autoStart;
  final bool showUpdates;
  final bool showDesktopWidget;
  final double memorySearchLimit;
  final bool apiLogEnabled;
  final List<ProviderConfig> providers;
  final Map<String, String?> defaultModels;
  final Map<String, String?> hotkeys;

  factory AppConfig.defaults() {
    return const AppConfig(
      dailyWorkHours: 8,
      dailySalary: 200,
      industry: '互联网',
      appFont: 'system',
      fontScale: 100,
      autoStart: false,
      showUpdates: true,
      showDesktopWidget: true,
      memorySearchLimit: 3,
      apiLogEnabled: false,
      providers: [],
      defaultModels: {
        'intelligentGenerationModel': null,
        'editCompletionModel': null,
        'memoryBookModel': null,
      },
      hotkeys: {'toggleWindow': 'Ctrl+Shift+S'},
    );
  }

  factory AppConfig.fromJson(Map<String, Object?> json) {
    return AppConfig(
      dailyWorkHours: _readDouble(json['dailyWorkHours'], 8),
      dailySalary: _readDouble(json['dailySalary'], 200),
      industry: json['industry'] as String? ?? '互联网',
      appFont: json['appFont'] as String? ?? 'system',
      fontScale: _readDouble(json['fontScale'], 100),
      autoStart: json['autoStart'] as bool? ?? false,
      showUpdates: json['showUpdates'] as bool? ?? true,
      showDesktopWidget: json['showDesktopWidget'] as bool? ?? true,
      memorySearchLimit: _readDouble(json['memorySearchLimit'], 3),
      apiLogEnabled: json['apiLogEnabled'] as bool? ?? false,
      providers: _readProviders(json['providers']),
      defaultModels: _readStringMap(
        json['defaultModels'],
        AppConfig.defaults().defaultModels,
      ),
      hotkeys: _readStringMap(json['hotkeys'], AppConfig.defaults().hotkeys),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'dailyWorkHours': dailyWorkHours,
      'dailySalary': dailySalary,
      'industry': industry,
      'appFont': appFont,
      'fontScale': fontScale,
      'autoStart': autoStart,
      'showUpdates': showUpdates,
      'showDesktopWidget': showDesktopWidget,
      'memorySearchLimit': memorySearchLimit,
      'apiLogEnabled': apiLogEnabled,
      'providers': providers.map((provider) => provider.toJson()).toList(),
      'defaultModels': defaultModels,
      'hotkeys': hotkeys,
    };
  }

  AppConfig copyWith({
    double? dailyWorkHours,
    double? dailySalary,
    String? industry,
    String? appFont,
    double? fontScale,
    bool? autoStart,
    bool? showUpdates,
    bool? showDesktopWidget,
    double? memorySearchLimit,
    bool? apiLogEnabled,
    List<ProviderConfig>? providers,
    Map<String, String?>? defaultModels,
    Map<String, String?>? hotkeys,
  }) {
    return AppConfig(
      dailyWorkHours: dailyWorkHours ?? this.dailyWorkHours,
      dailySalary: dailySalary ?? this.dailySalary,
      industry: industry ?? this.industry,
      appFont: appFont ?? this.appFont,
      fontScale: fontScale ?? this.fontScale,
      autoStart: autoStart ?? this.autoStart,
      showUpdates: showUpdates ?? this.showUpdates,
      showDesktopWidget: showDesktopWidget ?? this.showDesktopWidget,
      memorySearchLimit: memorySearchLimit ?? this.memorySearchLimit,
      apiLogEnabled: apiLogEnabled ?? this.apiLogEnabled,
      providers: providers ?? this.providers,
      defaultModels: defaultModels ?? this.defaultModels,
      hotkeys: hotkeys ?? this.hotkeys,
    );
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  static List<ProviderConfig> _readProviders(Object? value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, value) => MapEntry(key.toString(), value)),
        )
        .map(ProviderConfig.fromJson)
        .toList();
  }

  static Map<String, String?> _readStringMap(
    Object? value,
    Map<String, String?> fallback,
  ) {
    final result = Map<String, String?>.from(fallback);
    if (value is Map) {
      for (final entry in value.entries) {
        result[entry.key.toString()] = entry.value?.toString();
      }
    }
    return result;
  }
}
