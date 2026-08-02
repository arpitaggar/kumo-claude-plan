enum TransportMode {
  flight('Flight'),
  train('Train'),
  bus('Bus'),
  car('Car'),
  motorcycle('Motorcycle'),
  ferry('Ferry'),
  walk('Walk'),
  other('Other');

  const TransportMode(this.label);

  final String label;
}
