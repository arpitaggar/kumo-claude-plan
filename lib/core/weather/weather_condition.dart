enum WeatherCondition {
  clear('Clear'),
  partlyCloudy('Partly cloudy'),
  cloudy('Cloudy'),
  fog('Fog'),
  drizzle('Drizzle'),
  rain('Rain'),
  snow('Snow'),
  thunderstorm('Thunderstorm'),
  unknown('Unknown');

  const WeatherCondition(this.label);

  final String label;
}
