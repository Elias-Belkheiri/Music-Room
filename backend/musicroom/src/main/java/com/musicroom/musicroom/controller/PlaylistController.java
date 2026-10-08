package com.musicroom.musicroom.controller;

import com.musicroom.musicroom.dto.*;
import com.musicroom.musicroom.exception.UnauthorizedException;
import com.musicroom.musicroom.service.PlaylistService;
import com.musicroom.musicroom.service.SubscriptionService;
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
@RequestMapping("/api/playlists")
@RequiredArgsConstructor
@Tag(name = "Playlist", description = "Gestion des playlists collaboratives")
public class PlaylistController {

    private final PlaylistService playlistService;
    private final SubscriptionService subscriptionService;

    @Operation(summary = "Créer une playlist")
    @PostMapping
    public ResponseEntity<PlaylistDto> createPlaylist(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody CreatePlaylistRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        if (!subscriptionService.isFeatureAllowed(userId, "playlist_create")) {
            throw new UnauthorizedException("Premium subscription required to create playlists");
        }
        return ResponseEntity.status(201)
                .body(playlistService.createPlaylist(userId, request));
    }

    @Operation(summary = "Mes playlists et celles auxquelles j'ai accès")
    @GetMapping
    public ResponseEntity<List<PlaylistDto>> getMyPlaylists(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.getMyPlaylists(userId));
    }

    @Operation(summary = "Liste toutes les playlists publiques")
    @GetMapping("/public")
    public ResponseEntity<List<PlaylistDto>> getPublicPlaylists() {
        return ResponseEntity.ok(playlistService.getPublicPlaylists());
    }

    @Operation(summary = "Playlists publiques d'un utilisateur")
    @GetMapping("/public/user/{userId}")
    public ResponseEntity<List<PlaylistDto>> getPublicPlaylistsByUser(@PathVariable UUID userId) {
        return ResponseEntity.ok(playlistService.getPublicPlaylistsByUser(userId));
    }

    @Operation(summary = "Détail d'une playlist")
    @GetMapping("/{id}")
    public ResponseEntity<PlaylistDto> getPlaylistById(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.getPlaylistById(id, userId));
    }

    @Operation(summary = "Modifier une playlist")
    @PutMapping("/{id}")
    public ResponseEntity<PlaylistDto> updatePlaylist(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestBody CreatePlaylistRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.updatePlaylist(userId, id, request));
    }

    @Operation(summary = "Supprimer une playlist")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePlaylist(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        playlistService.deletePlaylist(userId, id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Inviter un utilisateur à la playlist")
    @PostMapping("/{id}/invite")
    public ResponseEntity<Void> inviteUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestBody InviteToPlaylistRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        playlistService.inviteUser(userId, id, request);
        return ResponseEntity.status(201).build();
    }

    @Operation(summary = "Voir les tracks de la playlist")
    @GetMapping("/{id}/tracks")
    public ResponseEntity<List<PlaylistTrackDto>> getPlaylistTracks(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.getPlaylistTracks(id, userId));
    }

    @Operation(summary = "Uploader une image pour la playlist")
    @PostMapping(value = "/{id}/cover",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<PlaylistDto> uploadCover(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @RequestParam(value = "cover", required = false) MultipartFile cover) {

        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.updatePlaylistCover(userId, id, cover));
    }

    @Operation(summary = "Sauvegarder une playlist")
    @PostMapping("/{id}/save")
    public ResponseEntity<Void> savePlaylist(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        playlistService.savePlaylist(userId, id);
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "Retirer une playlist des sauvegardes")
    @DeleteMapping("/{id}/save")
    public ResponseEntity<Void> unsavePlaylist(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        playlistService.unsavePlaylist(userId, id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Vérifier si une playlist est sauvegardée")
    @GetMapping("/{id}/saved")
    public ResponseEntity<Boolean> isPlaylistSaved(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.isPlaylistSaved(userId, id));
    }

    @Operation(summary = "Liste des playlists sauvegardées")
    @GetMapping("/saved")
    public ResponseEntity<List<PlaylistDto>> getSavedPlaylists(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.getSavedPlaylists(userId));
    }

    @Operation(summary = "Obtenir les collaborateurs d'une playlist")
    @GetMapping("/{id}/collaborators")
    public ResponseEntity<List<PlaylistCollaboratorDto>> getPlaylistCollaborators(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(playlistService.getPlaylistCollaborators(id, userId));
    }

    @Operation(summary = "Modifier le rôle d'un collaborateur d'une playlist")
    @PutMapping("/{id}/collaborators/{collaboratorId}")
    public ResponseEntity<Void> updateCollaboratorRole(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @PathVariable UUID collaboratorId,
            @RequestBody UpdatePlaylistCollaboratorRoleRequest request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        playlistService.updateCollaboratorRole(userId, id, collaboratorId, request.getPermission());
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "Retirer un collaborateur d'une playlist")
    @DeleteMapping("/{id}/collaborators/{collaboratorId}")
    public ResponseEntity<Void> removeCollaborator(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id,
            @PathVariable UUID collaboratorId) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        playlistService.removeCollaborator(userId, id, collaboratorId);
        return ResponseEntity.noContent().build();
    }
}