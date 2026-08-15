import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/geocoding/geocoding_providers.dart';
import '../../../../core/geocoding/geocoding_service.dart';
import '../../../../core/geocoding/gpx_parser.dart';

/// A bottom sheet returning a chosen [GeocodingResult], used for picking a
/// trip segment's origin/destination. Three ways in: live name search
/// (debounced, hits Nominatim), pasting raw GPS coordinates, or importing a
/// `.gpx` file and picking one of its waypoints — all three just produce the
/// same `{name, lat, lng}` shape, so nothing downstream of this sheet needs
/// to know which one was used.
class LocationSearchSheet extends ConsumerStatefulWidget {
  const LocationSearchSheet({super.key, this.title = 'Search location'});

  final String title;

  @override
  ConsumerState<LocationSearchSheet> createState() =>
      _LocationSearchSheetState();
}

class _LocationSearchSheetState extends ConsumerState<LocationSearchSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // ── Search tab ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<GeocodingResult> _results = [];
  bool _loading = false;
  String? _error;

  // ── Coordinates tab ─────────────────────────────────────────────────────
  final _coordsCtrl = TextEditingController();
  String? _coordsError;

  // ── Import GPX tab ──────────────────────────────────────────────────────
  List<GeocodingResult>? _gpxPoints;
  String? _gpxError;
  bool _gpxLoading = false;

  @override
  void dispose() {
    _tabs.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _coordsCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await ref.read(geocodingServiceProvider).search(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Search failed. Please try again.';
      });
    }
  }

  void _submitCoordinates() {
    final parsed = _parseCoordinates(_coordsCtrl.text);
    if (parsed == null) {
      setState(
        () => _coordsError = 'Enter coordinates like "35.6762, 139.6503"',
      );
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  Future<void> _pickGpxFile() async {
    setState(() {
      _gpxLoading = true;
      _gpxError = null;
      _gpxPoints = null;
    });
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );
      final path = picked?.path;
      if (path == null) {
        if (mounted) {
          setState(() => _gpxLoading = false);
        }
        return;
      }
      final raw = await File(path).readAsString();
      final points = parseGpxWaypoints(raw);
      if (!mounted) {
        return;
      }
      setState(() {
        _gpxPoints = points;
        _gpxLoading = false;
      });
    } on GpxParseException catch (e) {
      if (mounted) {
        setState(() {
          _gpxError = e.message;
          _gpxLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpxError = 'Could not read that file.';
          _gpxLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Search'),
              Tab(text: 'Coordinates'),
              Tab(text: 'Import GPX'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildSearchTab(scrollCtrl),
                _buildCoordinatesTab(),
                _buildGpxTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(ScrollController scrollCtrl) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for a city or place…',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: _onChanged,
        ),
      ),
      Expanded(child: _buildSearchResults(scrollCtrl)),
    ],
  );

  Widget _buildSearchResults(ScrollController scrollCtrl) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchCtrl.text.isEmpty
              ? 'Type to search for a city or place'
              : 'No results',
        ),
      );
    }
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final result = _results[i];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(result.name),
          onTap: () => Navigator.of(context).pop(result),
        );
      },
    );
  }

  Widget _buildCoordinatesTab() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste GPS coordinates as decimal degrees, e.g. '
          '"35.6762, 139.6503".',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _coordsCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            hintText: 'lat, lng',
            prefixIcon: const Icon(Icons.my_location_outlined),
            errorText: _coordsError,
          ),
          onChanged: (_) {
            if (_coordsError != null) {
              setState(() => _coordsError = null);
            }
          },
          onSubmitted: (_) => _submitCoordinates(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitCoordinates,
          child: const Text('Use this location'),
        ),
      ],
    ),
  );

  Widget _buildGpxTab() {
    if (_gpxLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final points = _gpxPoints;
    if (points != null) {
      return ListView.builder(
        itemCount: points.length,
        itemBuilder: (_, i) {
          final point = points[i];
          return ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(point.name),
            subtitle: Text(
              '${point.latitude.toStringAsFixed(5)}, '
              '${point.longitude.toStringAsFixed(5)}',
            ),
            onTap: () => Navigator.of(context).pop(point),
          );
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_gpxError != null) ...[
              Text(_gpxError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ] else ...[
              const Text(
                'Import a .gpx file exported from a GPS device or app to '
                'pick one of its waypoints.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _pickGpxFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Choose .gpx file'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parses free-form "lat, lng" (or "lat lng") text into a [GeocodingResult],
/// or null if the text doesn't contain two valid, in-range coordinates.
GeocodingResult? _parseCoordinates(String input) {
  final numbers = RegExp(
    r'-?\d+(\.\d+)?',
  ).allMatches(input).map((m) => m.group(0)!).toList();
  if (numbers.length < 2) {
    return null;
  }
  final lat = double.tryParse(numbers[0]);
  final lng = double.tryParse(numbers[1]);
  if (lat == null ||
      lng == null ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180) {
    return null;
  }
  return GeocodingResult(
    name: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
    latitude: lat,
    longitude: lng,
  );
}
