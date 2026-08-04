import '../../features/itinerary/domain/entities/transport_mode.dart';

/// The visual line style drawn along a segment's route, standing in for the
/// mode of transport the way a physical trail marker would: footprints for
/// walking, tyre tread for wheeled road transport, rails for a train.
enum RouteTexture {
  /// A single row of paired footprints.
  footsteps,

  /// One tyre track: a thin line with perpendicular tread dashes.
  singleTread,

  /// Two tyre tracks with directional chevrons between them.
  doubleTread,

  /// Two rails with perpendicular sleepers.
  trainTrack,

  /// A plain dashed line — flight/ferry/other legs don't leave ground tracks.
  dashedLine,
}

RouteTexture textureForMode(TransportMode mode) => switch (mode) {
  TransportMode.walk => RouteTexture.footsteps,
  TransportMode.motorcycle => RouteTexture.singleTread,
  TransportMode.car => RouteTexture.doubleTread,
  TransportMode.bus => RouteTexture.doubleTread,
  TransportMode.train => RouteTexture.trainTrack,
  TransportMode.flight => RouteTexture.dashedLine,
  TransportMode.ferry => RouteTexture.dashedLine,
  TransportMode.other => RouteTexture.dashedLine,
};

/// How many texture ticks (footprints / tread dashes / chevrons / sleepers)
/// to draw along a segment, regardless of its geographic length.
///
/// The OSM engine no longer uses this at all — every non-`dashedLine`
/// texture there now spaces its own ticks at a constant *pixel* interval
/// instead of a fixed count (see `_footstepsTickCount`/`_motoTreadTickCount`/
/// `_carTreadTickCount`/`_trainTrackTickCount` in route_line_painter.dart),
/// so density reads the same whether the leg is a short local hop or spans
/// most of the visible map, rather than the same handful of ticks spreading
/// thinner as the segment gets longer on-screen. The Google engine has no
/// equivalent — it samples in geographic coordinates, where "constant pixel
/// spacing" isn't meaningful without live zoom — so this function still
/// exists (and is only called) for that engine, with values raised from
/// each texture's original fixed count to read closer to the OSM engine's
/// new, tighter density.
int tickCountForTexture(RouteTexture texture) => switch (texture) {
  RouteTexture.footsteps => 32,
  RouteTexture.singleTread => 40,
  RouteTexture.doubleTread => 60,
  RouteTexture.trainTrack => 21,
  RouteTexture.dashedLine => 0,
};
