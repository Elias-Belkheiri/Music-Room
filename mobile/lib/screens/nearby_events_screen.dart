import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/event_service.dart';
import 'event_detail_screen.dart';

/// Screen for Bonus VI.2 (IoT / Beacon & Proximity Event Discovery)
class NearbyEventsScreen extends StatefulWidget {
  const NearbyEventsScreen({super.key});

  @override
  State<NearbyEventsScreen> createState() => _NearbyEventsScreenState();
}

class _NearbyEventsScreenState extends State<NearbyEventsScreen> {
  final EventService _eventService = EventService();

  double _radiusKm = 5.0;
  // Default coordinates (can be adjusted to simulate walking near a venue)
  double _currentLat = 48.8566;
  double _currentLng = 2.3522;
  bool _isLoading = false;
  List<Map<String, dynamic>> _nearbyEvents = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNearbyEvents();
  }

  Future<void> _fetchNearbyEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = Provider.of<AuthProvider>(context, listen: false)
        .currentUser
        ?.accessToken;

    try {
      final events = await _eventService.getNearbyEvents(
        lat: _currentLat,
        lng: _currentLng,
        radiusKm: _radiusKm,
        token: token,
      );
      if (mounted) {
        setState(() {
          _nearbyEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nearby Live Events (IoT)',
          style: AppTheme.titleLg.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
            onPressed: _fetchNearbyEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Beacon / Proximity Controls Header ────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.surfaceRaised),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching_rounded,
                        color: AppTheme.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'iBeacon / Geofence Radar',
                            style: AppTheme.titleMd.copyWith(fontSize: 15),
                          ),
                          Text(
                            'Detecting public music rooms nearby',
                            style: AppTheme.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        '${_radiusKm.toStringAsFixed(1)} km',
                        style: AppTheme.label.copyWith(
                          color: AppTheme.onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: AppTheme.surfaceRaised,
                    thumbColor: AppTheme.accent,
                    overlayColor: AppTheme.accent.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _radiusKm,
                    min: 0.5,
                    max: 20.0,
                    divisions: 39,
                    onChanged: (val) => setState(() => _radiusKm = val),
                    onChangeEnd: (_) => _fetchNearbyEvents(),
                  ),
                ),
              ],
            ),
          ),

          // ── Events List ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_off_rounded,
                                size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 12),
                            Text('Could not scan nearby events',
                                style: AppTheme.titleMd),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: AppTheme.onAccent,
                              ),
                              onPressed: _fetchNearbyEvents,
                              child: const Text('Retry Scan'),
                            ),
                          ],
                        ),
                      )
                    : _nearbyEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.radar_rounded,
                                    size: 56, color: AppTheme.textSecondary),
                                const SizedBox(height: 16),
                                Text(
                                  'No active rooms within ${_radiusKm.toStringAsFixed(1)} km',
                                  style: AppTheme.titleMd.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try increasing the radar search radius above.',
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _nearbyEvents.length,
                            itemBuilder: (context, i) {
                              final event = _nearbyEvents[i];
                              final String id = event['id']?.toString() ?? '';
                              final String name =
                                  event['name']?.toString() ?? 'Live Room';
                              final String? desc = event['description']?.toString();
                              final int listeners =
                                  (event['participantCount'] ??
                                          event['activeListeners'] ??
                                          1) as int;
                              final bool isPlaying = event['playing'] == true;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                    color: isPlaying
                                        ? AppTheme.accent.withValues(alpha: 0.4)
                                        : AppTheme.surfaceRaised,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceRaised,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm),
                                      ),
                                      child: Icon(
                                        isPlaying
                                            ? Icons.volume_up_rounded
                                            : Icons.music_note_rounded,
                                        color: isPlaying
                                            ? AppTheme.accent
                                            : AppTheme.textSecondary,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: AppTheme.titleMd
                                                .copyWith(fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            desc != null && desc.isNotEmpty
                                                ? desc
                                                : '$listeners listening now',
                                            style: AppTheme.caption
                                                .copyWith(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        foregroundColor: AppTheme.onAccent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusPill),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EventDetailScreen(
                                              eventId: id,
                                              eventName: name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Join',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
