package com.musicroom.musicroom.service.impl;

import com.musicroom.musicroom.dto.*;
import com.musicroom.musicroom.entity.*;
import com.musicroom.musicroom.exception.ConflictException;
import com.musicroom.musicroom.exception.ResourceNotFoundException;
import com.musicroom.musicroom.exception.UnauthorizedException;
import com.musicroom.musicroom.repository.*;
import com.musicroom.musicroom.service.EventService;
import com.musicroom.musicroom.service.PlaybackService;
import com.musicroom.musicroom.dto.websocket.VoteMessageType;
import com.musicroom.musicroom.dto.websocket.VoteUpdateMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.musicroom.musicroom.exception.BadRequestException;
import java.io.IOException;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class EventServiceImpl implements EventService {

    private final EventRepository eventRepo;
    private final UserRepository userRepo;
    private final EventInviteRepository inviteRepo;
    private final EventPlaylistRepository playlistRepo;
    private final VoteRepository voteRepo;
    private final TrackRepository trackRepo;
    private final SimpMessagingTemplate messagingTemplate;
    private final PlaybackService playbackService;

    @org.springframework.beans.factory.annotation.Autowired
    @org.springframework.context.annotation.Lazy
    private com.musicroom.musicroom.controller.WebSocketEventListener webSocketEventListener;

    @Override
    @Transactional
    public EventDto createEvent(UUID ownerId, CreateEventRequest request) {
        User owner = userRepo.findById(ownerId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Event event = Event.builder()
                .owner(owner)
                .name(request.getName())
                .description(request.getDescription())
                .visibility(request.getVisibility() != null ? request.getVisibility() : "public")
                .licenseType(request.getLicenseType() != null ? request.getLicenseType() : "open")
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .startsAt(request.getStartsAt())
                .endsAt(request.getEndsAt())
                .active(true)
                .build();

        eventRepo.save(event);
        EventDto dto = toDto(event);

        if ("public".equalsIgnoreCase(event.getVisibility())) {
            try {
                messagingTemplate.convertAndSend("/topic/events", java.util.Map.of(
                    "type", "EVENT_CREATED",
                    "event", dto
                ));
            } catch (Exception e) {
                log.error("Failed to broadcast EVENT_CREATED to /topic/events", e);
            }
        }

        return dto;
    }

    @Override
    @Transactional(readOnly = true)
    public List<EventDto> getAllPublicEvents(UUID userId) {
        return eventRepo.findActivePublicOwnedOrInvitedEvents(userId)
                .stream()
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<EventDto> getNearbyEvents(double lat, double lng, double radiusKm) {
        List<Event> publicEvents = eventRepo.findByVisibilityAndActiveTrue("public");
        return publicEvents.stream()
                .filter(e -> e.getLatitude() != null && e.getLongitude() != null)
                .filter(e -> haversineDistance(lat, lng, e.getLatitude(), e.getLongitude()) <= radiusKm)
                .sorted((e1, e2) -> Double.compare(
                        haversineDistance(lat, lng, e1.getLatitude(), e1.getLongitude()),
                        haversineDistance(lat, lng, e2.getLatitude(), e2.getLongitude())
                ))
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    private double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371.0; // Earth's radius in km
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    private void checkEventAccess(Event event, UUID userId) {
        String visibility = event.getVisibility() != null ? event.getVisibility() : "public";
        if ("private".equalsIgnoreCase(visibility)) {
            boolean isOwner = event.getOwner().getId().equals(userId);
            if (!isOwner) {
                boolean isInvited = inviteRepo.existsByEventIdAndUserId(event.getId(), userId);
                if (!isInvited) {
                    throw new UnauthorizedException("You do not have access to this private event.");
                }
            }
        }
    }

    @Override
    @Transactional(readOnly = true)
    public EventDto getEventById(UUID userId, UUID eventId) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
        checkEventAccess(event, userId);
        return toDto(event);
    }

    @Override
    @Transactional
    public EventDto updateEvent(UUID ownerId, UUID eventId, CreateEventRequest request) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOwner().getId().equals(ownerId)) {
            throw new UnauthorizedException("Not authorized to update this event");
        }

        if (request.getName() != null) event.setName(request.getName());
        if (request.getDescription() != null) event.setDescription(request.getDescription());
        if (request.getVisibility() != null) event.setVisibility(request.getVisibility());
        if (request.getLicenseType() != null) event.setLicenseType(request.getLicenseType());
        if (request.getStartsAt() != null) event.setStartsAt(request.getStartsAt());
        if (request.getEndsAt() != null) event.setEndsAt(request.getEndsAt());

        eventRepo.save(event);
        EventDto dto = toDto(event);

        if ("public".equalsIgnoreCase(event.getVisibility())) {
            try {
                messagingTemplate.convertAndSend("/topic/events", java.util.Map.of(
                    "type", "EVENT_UPDATED",
                    "event", dto
                ));
            } catch (Exception e) {
                log.error("Failed to broadcast EVENT_UPDATED to /topic/events", e);
            }
        } else {
            // Private event: Broadcast update to all invited guests
            List<EventInvite> invites = inviteRepo.findByEventId(eventId);
            for (EventInvite invite : invites) {
                try {
                    messagingTemplate.convertAndSend("/topic/user/" + invite.getUser().getId() + "/events", java.util.Map.of(
                        "type", "EVENT_UPDATED",
                        "event", dto
                    ));
                } catch (Exception e) {
                    log.error("Failed to broadcast EVENT_UPDATED to personal user events topic", e);
                }
            }
        }

        // Broadcast event updates (name, description, visibility)
        broadcastEventUpdate(eventId, "EVENT_UPDATED", java.util.Map.of(
            "name", event.getName() != null ? event.getName() : "",
            "description", event.getDescription() != null ? event.getDescription() : "",
            "visibility", event.getVisibility() != null ? event.getVisibility() : "public"
        ));

        return dto;
    }

    @Override
    @Transactional
    public void deleteEvent(UUID ownerId, UUID eventId) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOwner().getId().equals(ownerId)) {
            throw new UnauthorizedException("Not authorized to delete this event");
        }

        event.setActive(false);
        eventRepo.save(event);

        if ("public".equalsIgnoreCase(event.getVisibility())) {
            try {
                messagingTemplate.convertAndSend("/topic/events", java.util.Map.of(
                    "type", "EVENT_DELETED",
                    "eventId", eventId.toString()
                ));
            } catch (Exception e) {
                log.error("Failed to broadcast EVENT_DELETED to /topic/events", e);
            }
        } else {
            // Private event: Broadcast deletion to all invited guests
            List<EventInvite> invites = inviteRepo.findByEventId(eventId);
            for (EventInvite invite : invites) {
                try {
                    messagingTemplate.convertAndSend("/topic/user/" + invite.getUser().getId() + "/events", java.util.Map.of(
                        "type", "EVENT_DELETED",
                        "eventId", eventId.toString()
                    ));
                } catch (Exception e) {
                    log.error("Failed to broadcast EVENT_DELETED to personal user events topic", e);
                }
            }
        }
    }

    @Override
    @Transactional
    public void deleteEventSystem(UUID eventId) {
        Event event = eventRepo.findById(eventId).orElse(null);
        if (event != null) {
            event.setActive(false);
            eventRepo.save(event);

            if ("public".equalsIgnoreCase(event.getVisibility())) {
                try {
                    messagingTemplate.convertAndSend("/topic/events", java.util.Map.of(
                        "type", "EVENT_DELETED",
                        "eventId", eventId.toString()
                    ));
                } catch (Exception e) {
                    log.error("Failed to broadcast EVENT_DELETED to /topic/events", e);
                }
            } else {
                // Private event: Broadcast deletion to all invited guests
                List<EventInvite> invites = inviteRepo.findByEventId(eventId);
                for (EventInvite invite : invites) {
                    try {
                        messagingTemplate.convertAndSend("/topic/user/" + invite.getUser().getId() + "/events", java.util.Map.of(
                            "type", "EVENT_DELETED",
                            "eventId", eventId.toString()
                        ));
                    } catch (Exception e) {
                        log.error("Failed to broadcast EVENT_DELETED to personal user events topic", e);
                    }
                }
            }
        }
    }

    @Override
    @Transactional
    public void inviteUser(UUID ownerId, UUID eventId, InviteUserRequest request) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOwner().getId().equals(ownerId)) {
            throw new UnauthorizedException("Not authorized to invite users to this event");
        }

        if (inviteRepo.existsByEventIdAndUserId(eventId, request.getUserId())) {
            throw new ConflictException("User already invited to this event");
        }

        User user = userRepo.findById(request.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        EventInvite invite = EventInvite.builder()
                .event(event)
                .user(user)
                .role(request.getRole() != null ? request.getRole() : "voter")
                .build();

        inviteRepo.save(invite);

        EventDto dto = toDto(event);

        // Broadcast role update
        String frontEndRole = "admin".equalsIgnoreCase(invite.getRole()) ? "editor" : "viewer";
        broadcastEventUpdate(eventId, "ROLE_CHANGE", java.util.Map.of("userId", request.getUserId().toString(), "role", frontEndRole));

        // If event is private, broadcast EVENT_CREATED to the invited user's personal topic
        if (!"public".equalsIgnoreCase(event.getVisibility())) {
            try {
                messagingTemplate.convertAndSend("/topic/user/" + request.getUserId() + "/events", java.util.Map.of(
                    "type", "EVENT_CREATED",
                    "event", dto
                ));
            } catch (Exception e) {
                log.error("Failed to broadcast EVENT_CREATED to personal user events topic", e);
            }
        }
    }

    @Override
    @Transactional(readOnly = true)
    public List<PlaylistEntryDto> getPlaylist(UUID userId, UUID eventId) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
        checkEventAccess(event, userId);

        List<EventPlaylistEntry> entries = playlistRepo.findByEventIdOrderBySuggestedAtAsc(eventId);
        if (entries.isEmpty()) {
            return new java.util.ArrayList<>();
        }

        // Sort with awareness of the currently playing track
        UUID currentPlayingId = playbackService.getCurrentlyPlayingEntryId(eventId);

        if (currentPlayingId != null) {
            // Pin the currently playing track at index 0, sort the rest by votes desc
            EventPlaylistEntry playingEntry = null;
            List<EventPlaylistEntry> remaining = new java.util.ArrayList<>();
            for (EventPlaylistEntry entry : entries) {
                if (entry.getId().equals(currentPlayingId)) {
                    playingEntry = entry;
                } else {
                    remaining.add(entry);
                }
            }

            remaining.sort((a, b) -> {
                int voteCompare = Integer.compare(b.getVoteCount(), a.getVoteCount());
                if (voteCompare != 0) return voteCompare;
                java.time.LocalDateTime aTime = a.getSuggestedAt() != null ? a.getSuggestedAt() : java.time.LocalDateTime.MIN;
                java.time.LocalDateTime bTime = b.getSuggestedAt() != null ? b.getSuggestedAt() : java.time.LocalDateTime.MIN;
                return aTime.compareTo(bTime);
            });

            entries = new java.util.ArrayList<>();
            if (playingEntry != null) {
                entries.add(playingEntry);
            }
            entries.addAll(remaining);
        } else {
            // No track currently playing — sort entirely by votes desc, then suggestedAt asc
            entries = new java.util.ArrayList<>(entries);
            entries.sort((a, b) -> {
                int voteCompare = Integer.compare(b.getVoteCount(), a.getVoteCount());
                if (voteCompare != 0) return voteCompare;
                java.time.LocalDateTime aTime = a.getSuggestedAt() != null ? a.getSuggestedAt() : java.time.LocalDateTime.MIN;
                java.time.LocalDateTime bTime = b.getSuggestedAt() != null ? b.getSuggestedAt() : java.time.LocalDateTime.MIN;
                return aTime.compareTo(bTime);
            });
        }

        return entries.stream()
                .map(this::toPlaylistEntryDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public PlaylistEntryDto suggestTrack(UUID userId, UUID eventId, SuggestTrackRequest request) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        boolean isOwner = event.getOwner().getId().equals(userId);
        if (!isOwner) {
            Optional<EventInvite> inviteOpt = inviteRepo.findByEventIdAndUserId(eventId, userId);
            if (inviteOpt.isPresent()) {
                EventInvite invite = inviteOpt.get();
                if (!"admin".equalsIgnoreCase(invite.getRole())) {
                    throw new UnauthorizedException("Viewers are not allowed to suggest tracks. You can only listen and vote.");
                }
            } else {
                String visibility = event.getVisibility() != null ? event.getVisibility() : "public";
                if (!"public".equalsIgnoreCase(visibility)) {
                    throw new UnauthorizedException("You do not have access to this event.");
                }
                throw new UnauthorizedException("Guest viewers are not allowed to suggest tracks. You can only listen and vote.");
            }
        }

        Track track = trackRepo
                .findByExternalIdAndProvider(request.getExternalId(), request.getProvider())
                .orElseGet(() -> trackRepo.save(Track.builder()
                        .externalId(request.getExternalId())
                        .provider(request.getProvider())
                        .title(request.getTitle())
                        .artist(request.getArtist())
                        .album(request.getAlbum())
                        .coverUrl(request.getCoverUrl())
                        .durationMs(request.getDurationMs())
                        .build()));

        if (playlistRepo.countByEventId(eventId) >= 15) {
            throw new BadRequestException("Event queue has reached the limit of 15 tracks.");
        }

        if (playlistRepo.existsByEventIdAndTrackId(eventId, track.getId())) {
            throw new ConflictException("Track already in playlist");
        }

        EventPlaylistEntry entry = EventPlaylistEntry.builder()
                .event(event)
                .track(track)
                .suggestedBy(user)
                .voteCount(0)
                .position(0)
                .status("queued")
                .build();

        playlistRepo.save(entry);
        broadcastPlaylistUpdate(eventId, userId, entry, VoteMessageType.PLAYLIST_UPDATED);

        // Notify playback engine (auto-plays if event is active and queue was empty)
        playbackService.onPlaylistChanged(eventId);

        return toPlaylistEntryDto(entry);
    }

    @Override
    @Transactional
    public void removeTrack(UUID userId, UUID eventId, UUID entryId) {
        if (!eventRepo.existsById(eventId)) {
            throw new ResourceNotFoundException("Event not found");
        }
        EventPlaylistEntry entry = playlistRepo.findById(entryId)
                .orElseThrow(() -> new ResourceNotFoundException("Playlist entry not found"));

        playlistRepo.delete(entry);
        playlistRepo.flush();
        broadcastPlaylistUpdate(eventId, userId, entry, VoteMessageType.PLAYLIST_UPDATED);

        // Notify playback engine
        playbackService.onPlaylistChanged(eventId);
    }

    @Override
    @Transactional
    public EventDto updateEventCover(UUID userId, UUID eventId,
                                  MultipartFile cover) {

        Event event = eventRepo.findById(eventId)
            .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOwner().getId().equals(userId)) {
                throw new UnauthorizedException("Not authorized to update this event");
        }

        if (cover != null && !cover.isEmpty()) {

                String contentType = cover.getContentType();
                if (contentType == null || !contentType.startsWith("image/")) {
                throw new BadRequestException("Le fichier doit être une image");
                }

                if (cover.getSize() > 2 * 1024 * 1024) {
                throw new BadRequestException("L'image ne doit pas dépasser 2MB");
                }

                try {
                byte[] bytes = cover.getBytes();
                String base64 = java.util.Base64.getEncoder().encodeToString(bytes);
                String dataUrl = "data:" + contentType + ";base64," + base64;
                event.setCoverUrl(dataUrl);
                } catch (IOException e) {
                throw new BadRequestException("Erreur lors de l'upload de l'image");
                }
        }

        eventRepo.save(event);
        return getEventById(userId, eventId);
    }

    @Override
    @Transactional
    public PlaylistEntryDto vote(UUID userId, UUID eventId, UUID entryId, VoteRequest request) {
        EventPlaylistEntry entry = playlistRepo.findById(entryId)
                .orElseThrow(() -> new ResourceNotFoundException("Playlist entry not found"));

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        java.util.Optional<Vote> existingOpt = voteRepo.findByPlaylistEntryIdAndUserId(entryId, userId);
        if (existingOpt.isPresent()) {
            Vote existingVote = existingOpt.get();
            if (existingVote.getValue() == request.getValue()) {
                // toggle off
                voteRepo.delete(existingVote);
                entry.setVoteCount(entry.getVoteCount() - existingVote.getValue());
            } else {
                int oldVal = existingVote.getValue();
                existingVote.setValue(request.getValue());
                voteRepo.save(existingVote);
                entry.setVoteCount(entry.getVoteCount() - oldVal + request.getValue());
            }
        } else {
            Vote vote = Vote.builder()
                    .playlistEntry(entry)
                    .user(user)
                    .value(request.getValue())
                    .build();
            voteRepo.save(vote);
            entry.setVoteCount(entry.getVoteCount() + request.getValue());
        }

        playlistRepo.save(entry);
        broadcastPlaylistUpdate(eventId, userId, entry, VoteMessageType.VOTE_CHANGED);
        return toPlaylistEntryDto(entry);
    }

    @Override
    @Transactional(readOnly = true)
    public java.util.Map<String, Object> getEventUserRole(UUID userId, UUID eventId) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        String visibility = event.getVisibility() != null ? event.getVisibility() : "public";
        boolean isOwner = event.getOwner().getId().equals(userId);

        if (isOwner) {
            return java.util.Map.of(
                "role", "owner",
                "allowed", true,
                "visibility", visibility,
                "locked", false
            );
        }

        Optional<EventInvite> inviteOpt = inviteRepo.findByEventIdAndUserId(eventId, userId);

        if (inviteOpt.isPresent()) {
            EventInvite invite = inviteOpt.get();
            String role = "admin".equalsIgnoreCase(invite.getRole()) ? "editor" : "viewer";
            return java.util.Map.of(
                "role", role,
                "allowed", true,
                "visibility", visibility,
                "locked", false
            );
        }

        // Lock event for new users if it has already started
        if (playbackService.isEventPlaying(eventId)) {
            return java.util.Map.of(
                "role", "none",
                "allowed", false,
                "visibility", visibility,
                "locked", true
            );
        }

        boolean isPublic = "public".equalsIgnoreCase(visibility);
        return java.util.Map.of(
            "role", isPublic ? "viewer" : "none",
            "allowed", isPublic,
            "visibility", visibility,
            "locked", false
        );
    }

    private EventDto toDto(Event event) {
        String firstTrackCover = null;
        if (event.getPlaylist() != null && !event.getPlaylist().isEmpty()) {
            EventPlaylistEntry first = event.getPlaylist().get(0);
            if (first.getTrack() != null) {
                firstTrackCover = first.getTrack().getCoverUrl();
            }
        }

        return EventDto.builder()
                .id(event.getId())
                .name(event.getName())
                .description(event.getDescription())
                .visibility(event.getVisibility())
                .licenseType(event.getLicenseType())
                .latitude(event.getLatitude())
                .longitude(event.getLongitude())
                .startsAt(event.getStartsAt())
                .endsAt(event.getEndsAt())
                .active(event.isActive())
                .isPlaying(playbackService != null && playbackService.isEventPlaying(event.getId()))
                .ownerId(event.getOwner().getId())
                .ownerName(event.getOwner().getDisplayName())
                .trackCount(event.getPlaylist() != null ? event.getPlaylist().size() : 0)
                .participantCount(webSocketEventListener != null ? webSocketEventListener.getListenerCount(event.getId()) : 0)
                .createdAt(event.getCreatedAt())
                .coverUrl(event.getCoverUrl())
                .firstTrackCoverUrl(firstTrackCover)
                .build();
    }

    private PlaylistEntryDto toPlaylistEntryDto(EventPlaylistEntry entry) {
        java.util.List<VoteDto> votedList = new java.util.ArrayList<>();
        java.util.List<Vote> votes = voteRepo.findByPlaylistEntryId(entry.getId());
        if (votes != null) {
            for (Vote v : votes) {
                votedList.add(VoteDto.builder()
                        .userId(v.getUser().getId())
                        .displayName(v.getUser().getDisplayName())
                        .value(v.getValue())
                        .build());
            }
        }
        return PlaylistEntryDto.builder()
                .id(entry.getId())
                .title(entry.getTrack().getTitle())
                .artist(entry.getTrack().getArtist())
                .coverUrl(entry.getTrack().getCoverUrl())
                .durationMs(entry.getTrack().getDurationMs())
                .voteCount(entry.getVoteCount())
                .position(entry.getPosition())
                .status(entry.getStatus())
                .suggestedById(entry.getSuggestedBy() != null ? entry.getSuggestedBy().getId() : null)
                .suggestedByName(entry.getSuggestedBy() != null ? entry.getSuggestedBy().getDisplayName() : null)
                .externalId(entry.getTrack().getExternalId())
                .votedUsers(votedList)
                .build();
    }

    private void broadcastPlaylistUpdate(UUID eventId, UUID userId, EventPlaylistEntry entry, VoteMessageType type) {
        List<EventPlaylistEntry> entries = playlistRepo.findByEventIdOrderBySuggestedAtAsc(eventId);

        // Sort with awareness of the currently playing track
        UUID currentPlayingId = playbackService.getCurrentlyPlayingEntryId(eventId);

        if (!entries.isEmpty()) {
            if (currentPlayingId != null) {
                EventPlaylistEntry playingEntry = null;
                List<EventPlaylistEntry> remaining = new java.util.ArrayList<>();
                for (EventPlaylistEntry e : entries) {
                    if (e.getId().equals(currentPlayingId)) {
                        playingEntry = e;
                    } else {
                        remaining.add(e);
                    }
                }

                remaining.sort((a, b) -> {
                    int voteCompare = Integer.compare(b.getVoteCount(), a.getVoteCount());
                    if (voteCompare != 0) return voteCompare;
                    java.time.LocalDateTime aTime = a.getSuggestedAt() != null ? a.getSuggestedAt() : java.time.LocalDateTime.MIN;
                    java.time.LocalDateTime bTime = b.getSuggestedAt() != null ? b.getSuggestedAt() : java.time.LocalDateTime.MIN;
                    return aTime.compareTo(bTime);
                });

                entries = new java.util.ArrayList<>();
                if (playingEntry != null) {
                    entries.add(playingEntry);
                }
                entries.addAll(remaining);
            } else {
                entries = new java.util.ArrayList<>(entries);
                entries.sort((a, b) -> {
                    int voteCompare = Integer.compare(b.getVoteCount(), a.getVoteCount());
                    if (voteCompare != 0) return voteCompare;
                    java.time.LocalDateTime aTime = a.getSuggestedAt() != null ? a.getSuggestedAt() : java.time.LocalDateTime.MIN;
                    java.time.LocalDateTime bTime = b.getSuggestedAt() != null ? b.getSuggestedAt() : java.time.LocalDateTime.MIN;
                    return aTime.compareTo(bTime);
                });
            }
        }

        List<PlaylistEntryDto> playlist = entries.stream()
                .map(this::toPlaylistEntryDto)
                .collect(Collectors.toList());

        VoteUpdateMessage updateMessage = VoteUpdateMessage.builder()
                .type(type)
                .eventId(eventId)
                .entryId(entry.getId())
                .userId(userId)
                .newVoteCount(entry.getVoteCount())
                .playlist(playlist)
                .build();

        messagingTemplate.convertAndSend(
                "/topic/event/" + eventId + "/playlist",
                updateMessage
        );
    }

    @Override
    @Transactional(readOnly = true)
    public java.util.List<java.util.Map<String, Object>> getCollaborators(UUID userId, UUID eventId) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        boolean isOwner = event.getOwner().getId().equals(userId);
        boolean hasInvite = inviteRepo.existsByEventIdAndUserId(eventId, userId);
        boolean isPublic = "public".equalsIgnoreCase(event.getVisibility());

        if (!isOwner && !hasInvite && !isPublic) {
            throw new UnauthorizedException("Not authorized to view collaborators for this event");
        }

        java.util.List<EventInvite> invites = inviteRepo.findByEventId(eventId);
        java.util.List<java.util.Map<String, Object>> result = new java.util.ArrayList<>();

        // Add owner first
        java.util.Map<String, Object> ownerMap = new java.util.HashMap<>();
        ownerMap.put("userId", event.getOwner().getId().toString());
        ownerMap.put("displayName", event.getOwner().getDisplayName());
        ownerMap.put("avatarUrl", event.getOwner().getAvatarUrl() != null ? event.getOwner().getAvatarUrl() : "");
        ownerMap.put("permission", "owner");
        result.add(ownerMap);

        for (EventInvite invite : invites) {
            java.util.Map<String, Object> cMap = new java.util.HashMap<>();
            cMap.put("userId", invite.getUser().getId().toString());
            cMap.put("displayName", invite.getUser().getDisplayName());
            cMap.put("avatarUrl", invite.getUser().getAvatarUrl() != null ? invite.getUser().getAvatarUrl() : "");
            cMap.put("permission", "admin".equalsIgnoreCase(invite.getRole()) ? "editor" : "viewer");
            result.add(cMap);
        }

        return result;
    }

    @Override
    @Transactional
    public void updateCollaboratorRole(UUID ownerId, UUID eventId, UUID collaboratorId, String role) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOwner().getId().equals(ownerId)) {
            throw new UnauthorizedException("Only the event owner can modify collaborator roles");
        }

        EventInvite invite = inviteRepo.findByEventIdAndUserId(eventId, collaboratorId)
                .orElse(null);

        if (invite == null) {
            User user = userRepo.findById(collaboratorId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found"));
            invite = new EventInvite();
            invite.setEvent(event);
            invite.setUser(user);
        }

        if ("editor".equalsIgnoreCase(role)) {
            invite.setRole("admin");
        } else {
            invite.setRole("voter");
        }
        inviteRepo.save(invite);

        // Broadcast role update
        String frontEndRole = "admin".equalsIgnoreCase(invite.getRole()) ? "editor" : "viewer";
        broadcastEventUpdate(eventId, "ROLE_CHANGE", java.util.Map.of("userId", collaboratorId.toString(), "role", frontEndRole));
    }

    @Override
    @Transactional
    public void removeCollaborator(UUID ownerId, UUID eventId, UUID collaboratorId) {
        Event event = eventRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOwner().getId().equals(ownerId)) {
            throw new UnauthorizedException("Only the event owner can remove collaborators");
        }

        EventInvite invite = inviteRepo.findByEventIdAndUserId(eventId, collaboratorId)
                .orElseThrow(() -> new ResourceNotFoundException("Collaborator not found"));

        inviteRepo.delete(invite);

        // Broadcast role update (role is 'none' when removed)
        broadcastEventUpdate(eventId, "ROLE_CHANGE", java.util.Map.of("userId", collaboratorId.toString(), "role", "none"));

        // If event is private, broadcast EVENT_DELETED to the removed user's personal topic
        if (!"public".equalsIgnoreCase(event.getVisibility())) {
            try {
                messagingTemplate.convertAndSend("/topic/user/" + collaboratorId + "/events", java.util.Map.of(
                    "type", "EVENT_DELETED",
                    "eventId", eventId.toString()
                ));
            } catch (Exception e) {
                log.error("Failed to broadcast EVENT_DELETED to personal user events topic on collaborator removal", e);
            }
        }
    }

    private void broadcastEventUpdate(UUID eventId, String type, java.util.Map<String, Object> extraData) {
        java.util.Map<String, Object> payload = new java.util.HashMap<>();
        payload.put("type", type);
        if (extraData != null) {
            payload.putAll(extraData);
        }
        messagingTemplate.convertAndSend("/topic/event/" + eventId + "/updates", payload);
    }
}