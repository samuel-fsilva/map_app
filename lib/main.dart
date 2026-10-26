import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MapApp());
}

class MapApp extends StatelessWidget {
  const MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My OSM Map',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class SavedPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  LatLng get point => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class _PlaceFormDialog extends StatefulWidget {
  const _PlaceFormDialog({this.place, this.draftPosition});

  final SavedPlace? place;
  final LatLng? draftPosition;

  @override
  State<_PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<_PlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place?.name ?? '');
    _latitudeController = TextEditingController(
      text:
          widget.place?.latitude.toString() ??
          widget.draftPosition?.latitude.toString() ??
          '',
    );
    _longitudeController = TextEditingController(
      text:
          widget.place?.longitude.toString() ??
          widget.draftPosition?.longitude.toString() ??
          '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  String? _validateCoordinate(
    String? value, {
    required double minimum,
    required double maximum,
    required String label,
  }) {
    final coordinate = double.tryParse(
      (value ?? '').trim().replaceAll(',', '.'),
    );
    if (coordinate == null ||
        !coordinate.isFinite ||
        coordinate < minimum ||
        coordinate > maximum) {
      return 'Enter a $label from $minimum to $maximum.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      SavedPlace(
        id:
            widget.place?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        latitude: double.parse(
          _latitudeController.text.trim().replaceAll(',', '.'),
        ),
        longitude: double.parse(
          _longitudeController.text.trim().replaceAll(',', '.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.place != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit marker' : 'Add marker'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Marker name',
                  hintText: 'e.g. Favorite park',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              TextFormField(
                controller: _latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
                validator: (value) => _validateCoordinate(
                  value,
                  minimum: -90,
                  maximum: 90,
                  label: 'latitude',
                ),
              ),
              TextFormField(
                controller: _longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
                validator: (value) => _validateCoordinate(
                  value,
                  minimum: -180,
                  maximum: 180,
                  label: 'longitude',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: Text(isEditing ? 'Save' : 'Add')),
      ],
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  static const LatLng _initialPosition = LatLng(-23.5505, -46.6333);

  static const double _minimumZoom = 2;
  static const double _maximumZoom = 19;

  static const String _storageKey = 'saved_places_v1';

  final List<SavedPlace> _places = [];

  LatLng? _currentPosition;
  LatLng? _draftPosition;

  bool _loading = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final loaded = decoded
            .map(
              (item) =>
                  SavedPlace.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

        if (mounted) {
          setState(() => _places.addAll(loaded));
        }
      }
    } catch (_) {
      if (mounted) {
        _message('Could not load saved places.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _persistPlaces() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(_places.map((p) => p.toJson()).toList()),
    );
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _zoomBy(double amount) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + amount).clamp(_minimumZoom, _maximumZoom);
    _mapController.move(camera.center, zoom);
  }

  Future<void> _showPlaceForm({SavedPlace? place}) async {
    final result = await showDialog<SavedPlace>(
      context: context,
      builder: (_) =>
          _PlaceFormDialog(place: place, draftPosition: _draftPosition),
    );
    if (!mounted) return;
    if (!mounted) return;
    if (result == null) return;

    if (place == null) {
      setState(() {
        _places.add(result);
        _draftPosition = null;
      });
    } else {
      final index = _places.indexWhere((item) => item.id == place.id);
      if (index == -1) return;
      setState(() => _places[index] = result);
    }

    try {
      await _persistPlaces();
      _message(place == null ? 'Marker added.' : 'Marker updated.');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (place == null) {
          _places.removeWhere((item) => item.id == result.id);
        } else {
          final index = _places.indexWhere((item) => item.id == result.id);
          if (index != -1) _places[index] = place;
        }
      });
      _message('Could not save marker. Please try again.');
    }
  }

  Future<void> _deletePlace(SavedPlace place) async {
    setState(() {
      _places.removeWhere((p) => p.id == place.id);
    });

    try {
      await _persistPlaces();
      _message('${place.name} deleted.');
    } catch (_) {
      if (!mounted) return;

      setState(() => _places.add(place));
      _message('Could not delete place.');
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_locating) return;

    setState(() => _locating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        _message('Turn on location services and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _message('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _message(
          'Location permission is blocked. Enable it in Android settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);

      setState(() => _currentPosition = point);

      _mapController.move(point, 16);
    } catch (error) {
      _message('Could not get location. Check GPS and permissions.');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Markers (${_places.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add marker',
                      onPressed: _showPlaceForm,
                      icon: const Icon(Icons.add_location_alt),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _places.isEmpty
                    ? const Center(child: Text('No markers yet.'))
                    : ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          return ListTile(
                            leading: const Icon(Icons.place),
                            title: Text(place.name),
                            subtitle: Text(
                              '${place.latitude.toStringAsFixed(5)}, '
                              '${place.longitude.toStringAsFixed(5)}',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _mapController.move(place.point, 16);
                            },
                            trailing: SizedBox(
                              width: 96,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit marker',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _showPlaceForm(place: place),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete marker',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deletePlace(place);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(title: const Text('My OSM Map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 13,
              minZoom: _minimumZoom,
              maxZoom: _maximumZoom,
              onTap: (tapPosition, point) {
                setState(() => _draftPosition = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.my_osm_map',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final place in _places)
                    Marker(
                      point: place.point,
                      width: 48,
                      height: 56,
                      child: GestureDetector(
                        onTap: () => _mapController.move(place.point, 16),
                        child: const Icon(
                          Icons.location_on,
                          size: 44,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  if (_draftPosition != null)
                    Marker(
                      point: _draftPosition!,
                      width: 44,
                      height: 48,
                      child: const Icon(
                        Icons.add_location_alt,
                        size: 40,
                        color: Colors.orange,
                      ),
                    ),
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.my_location,
                        size: 30,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () {
                      _message('Map data © OpenStreetMap contributors');
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_loading)
            const Positioned(
              top: 12,
              left: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Loading saved places...'),
                ),
              ),
            ),
          if (_draftPosition != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Selected location')),
                      TextButton(
                        onPressed: () {
                          setState(() => _draftPosition = null);
                        },
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: _showPlaceForm,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => _zoomBy(1),
                    icon: const Icon(Icons.add),
                  ),
                  const Divider(height: 1),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => _zoomBy(-1),
                    icon: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'current-location',
        tooltip: 'Find my location',
        onPressed: _locating ? null : _goToCurrentLocation,
        child: _locating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}
