class F1Car {
  final int number;
  final String driverName;
  final String teamName;
  final String version;
  final String? ipAddress;
  final int? port;

  const F1Car({
    required this.number,
    required this.driverName,
    required this.teamName,
    required this.version,
    this.ipAddress,
    this.port,
  });
}
