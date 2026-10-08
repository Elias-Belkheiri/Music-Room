package com.musicroom.musicroom.service;

import com.musicroom.musicroom.dto.*;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.web.multipart.MultipartFile;

public interface EventService {
    EventDto createEvent(UUID ownerId, CreateEventRequest request);
    List<EventDto> getAllPublicEvents(UUID userId);
    List<EventDto> getNearbyEvents(double lat, double lng, double radiusKm);
    EventDto getEventById(UUID userId, UUID eventId);
    EventDto updateEvent(UUID ownerId, UUID eventId, CreateEventRequest request);
    void deleteEvent(UUID ownerId, UUID eventId);
    void deleteEventSystem(UUID eventId);
    void inviteUser(UUID ownerId, UUID eventId, InviteUserRequest request);
    List<PlaylistEntryDto> getPlaylist(UUID userId, UUID eventId);
    PlaylistEntryDto suggestTrack(UUID userId, UUID eventId, SuggestTrackRequest request);
    void removeTrack(UUID userId, UUID eventId, UUID entryId);
    PlaylistEntryDto vote(UUID userId, UUID eventId, UUID entryId, VoteRequest request);
    EventDto updateEventCover(UUID userId, UUID eventId, MultipartFile cover);
    Map<String, Object> getEventUserRole(UUID userId, UUID eventId);
    List<Map<String, Object>> getCollaborators(UUID userId, UUID eventId);
    void updateCollaboratorRole(UUID ownerId, UUID eventId, UUID collaboratorId, String role);
    void removeCollaborator(UUID ownerId, UUID eventId, UUID collaboratorId);
}