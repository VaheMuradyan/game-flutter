class Environment {
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://localhost:8080',
  );

  static const String wsHost = String.fromEnvironment(
    'WS_HOST',
    defaultValue: 'ws://localhost:8080',
  );
}
