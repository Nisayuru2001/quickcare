import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickcare_user/services/location_service.dart';

class LocationPicker extends StatefulWidget {
  final Function(LatLng) onLocationSelected;
  final LatLng? initialLocation;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      setState(() {
        _selectedLocation = widget.initialLocation;
        _isLoading = false;
      });
      return;
    }

    Position? position = await LocationService.getCurrentLocation(
      context: context,
      showErrors: true,
    );

    if (position != null) {
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } else {
      // Default to a fallback location (e.g., city center)
      setState(() {
        _selectedLocation = const LatLng(6.9271, 79.8612); // Colombo, Sri Lanka
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation!,
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _selectedLocation == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedLocation!,
                        draggable: true,
                        onDragEnd: (newPosition) {
                          setState(() {
                            _selectedLocation = newPosition;
                            widget.onLocationSelected(newPosition);
                          });
                        },
                      ),
                    },
              onTap: (position) {
                setState(() {
                  _selectedLocation = position;
                  widget.onLocationSelected(position);
                });
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            Position? position = await LocationService.getCurrentLocation(
              context: context,
              showErrors: true,
            );
            if (position != null) {
              final location = LatLng(position.latitude, position.longitude);
              setState(() {
                _selectedLocation = location;
              });
              widget.onLocationSelected(location);
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(location),
              );
            }
          },
          icon: const Icon(Icons.my_location),
          label: const Text('Use Current Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 