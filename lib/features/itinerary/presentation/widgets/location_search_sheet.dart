import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/geocoding/geocoding_providers.dart';
import '../../../../core/geocoding/geocoding_service.dart';

/// A live-search bottom sheet returning a chosen [GeocodingResult], used for
/// picking a trip segment's origin/destination. Debounces keystrokes before
/// hitting the network — the geocoding service itself also throttles actual
/// requests to respect Nominatim's rate limit.
class LocationSearchSheet extends ConsumerStatefulWidget {
  const LocationSearchSheet({super.key, this.title = 'Search location'});

  final String title;

  @override
  ConsumerState<LocationSearchSheet> createState() =>
      _LocationSearchSheetState();
}

class _LocationSearchSheetState extends ConsumerState<LocationSearchSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<GeocodingResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
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
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed. Please try again.';
      });
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          const Divider(height: 1),
          Expanded(child: _buildBody(scrollCtrl)),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollCtrl) {
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
}
