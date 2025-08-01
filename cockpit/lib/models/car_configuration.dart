class CarConfiguration {
  final int number;
  final String driverName, teamName;

  const CarConfiguration({
    required this.number,
    required this.driverName,
    required this.teamName,
  });

  factory CarConfiguration.fromJson(Map<String, dynamic> json) =>
      CarConfiguration(
        number: json['number'],
        driverName: json['driver_name'],
        teamName: json['team_name'],
      );

  Map<String, dynamic> toJson() => {
    'number': number,
    'driver_name': driverName,
    'team_name': teamName,
  };
}
