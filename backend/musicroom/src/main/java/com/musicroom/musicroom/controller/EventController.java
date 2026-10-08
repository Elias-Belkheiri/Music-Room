package com.musicroom.musicroom.controller;

import com.musicroom.musicroom.dto.*;
import com.musicroom.musicroom.service.EventService;
import com.musicroom.musicroom.service.PlaybackService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.http.MediaType;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/events")
@RequiredArgsConstructor
@Tag(name = "Event", description = "Gestion des événements musicaux")
public class EventController {

    private final EventService eventService;
    private final WebSocketEventListener webSocketEventListener;
    private final PlaybackService playbackService;

    @Operation(summary = "Créer un événement")
    @PostMapping
    public ResponseEntity<EventDto> createEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody CreateEventRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.status(201).body(eventService.createEvent(userId, request));
    }

    @Operation(summary = "Liste tous les événements publics")
    @GetMapping
    public ResponseEntity<List<EventDto>> getAllPublicEvents(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getAllPublicEvents(userId));
    }

    @GetMapping("/nearby")
    @Operation(summary = "Find active public events near a location")
    public ResponseEntity<?> getNearbyEvents(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(defaultValue = "1.0") double radiusKm) {
        return ResponseEntity.ok(eventService.getNearbyEvents(lat, lng, radiusKm));
    }

    @Operation(summary = "Détail d'un événement")
    @GetMapping("/{id}")
    public ResponseEntity<EventDto> getEventById(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getEventById(userId, id));
    }

    @Operation(summary = "Modifier un événement")
    @PutMapping("/{id}")
    public ResponseEntity<EventDto> updateEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestBody CreateEventRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.updateEvent(userId, id, request));
    }

    @Operation(summary = "Supprimer un événement")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.deleteEvent(userId, id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Inviter un utilisateur à l'événement")
    @PostMapping("/{id}/invite")
    public ResponseEntity<Void> inviteUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestBody InviteUserRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.inviteUser(userId, id, request);
        return ResponseEntity.status(201).build();
    }

    @Operation(summary = "Voir la playlist de l'événement")
    @GetMapping("/{id}/playlist")
    public ResponseEntity<List<PlaylistEntryDto>> getPlaylist(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getPlaylist(userId, id));
    }

    @Operation(summary = "Suggérer une track")
    @PostMapping("/{id}/playlist")
    public ResponseEntity<PlaylistEntryDto> suggestTrack(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestBody SuggestTrackRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.status(201).body(eventService.suggestTrack(userId, id, request));
    }

    @Operation(summary = "Supprimer une track de la playlist")
    @DeleteMapping("/{id}/playlist/{entryId}")
    public ResponseEntity<Void> removeTrack(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @PathVariable UUID entryId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.removeTrack(userId, id, entryId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Voter pour une track")
    @PostMapping("/{id}/playlist/{entryId}/vote")
    public ResponseEntity<PlaylistEntryDto> vote(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @PathVariable UUID entryId,
            @RequestBody VoteRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.vote(userId, id, entryId, request));
    }

    @Operation(summary = "Obtenir le rôle de l'utilisateur dans l'événement")
    @GetMapping("/{id}/role")
    public ResponseEntity<java.util.Map<String, Object>> getEventUserRole(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getEventUserRole(userId, id));
    }

    @Operation(summary = "Uploader une image pour l'événement")
    @PostMapping(value = "/{id}/cover",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<EventDto> uploadCover(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestParam(value = "cover", required = false) MultipartFile cover) {

        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.updateEventCover(userId, id, cover));
    }

    @Operation(summary = "Obtenir les collaborateurs de l'événement")
    @GetMapping("/{id}/collaborators")
    public ResponseEntity<List<java.util.Map<String, Object>>> getCollaborators(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(eventService.getCollaborators(userId, id));
    }

    @Operation(summary = "Mettre à jour le rôle d'un collaborateur")
    @PutMapping("/{id}/collaborators/{collaboratorId}/role")
    public ResponseEntity<Void> updateCollaboratorRole(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @PathVariable UUID collaboratorId,
            @RequestParam String role) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.updateCollaboratorRole(userId, id, collaboratorId, role);
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "Supprimer un collaborateur")
    @DeleteMapping("/{id}/collaborators/{collaboratorId}")
    public ResponseEntity<Void> removeCollaborator(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @PathVariable UUID collaboratorId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.removeCollaborator(userId, id, collaboratorId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Obtenir les auditeurs actifs de l'événement")
    @GetMapping("/{id}/listeners")
    public ResponseEntity<List<java.util.Map<String, Object>>> getActiveListeners(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.getEventById(userId, id); // Access guard
        return ResponseEntity.ok(webSocketEventListener.getActiveListeners(id));
    }

    @Operation(summary = "Vérifier si l'événement est en cours de lecture")
    @GetMapping("/{id}/playback-status")
    public ResponseEntity<java.util.Map<String, Object>> getPlaybackStatus(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        eventService.getEventById(userId, id); // Access guard
        return ResponseEntity.ok(playbackService.getPlaybackStatus(id));
    }
}