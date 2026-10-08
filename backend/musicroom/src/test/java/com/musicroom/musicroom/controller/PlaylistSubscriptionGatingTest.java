package com.musicroom.musicroom.controller;

import com.musicroom.musicroom.dto.CreatePlaylistRequest;
import com.musicroom.musicroom.dto.PlaylistDto;
import com.musicroom.musicroom.exception.UnauthorizedException;
import com.musicroom.musicroom.service.PlaylistService;
import com.musicroom.musicroom.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PlaylistSubscriptionGatingTest {

    @Mock
    private PlaylistService playlistService;

    @Mock
    private SubscriptionService subscriptionService;

    @Mock
    private UserDetails userDetails;

    private PlaylistController playlistController;
    private UUID userId;

    @BeforeEach
    void setUp() {
        playlistController = new PlaylistController(playlistService, subscriptionService);
        userId = UUID.randomUUID();
        when(userDetails.getUsername()).thenReturn(userId.toString());
    }

    @Test
    void createPlaylist_whenFreeUser_shouldThrowUnauthorizedException() {
        CreatePlaylistRequest req = new CreatePlaylistRequest();
        req.setName("Summer Hits");

        when(subscriptionService.isFeatureAllowed(userId, "playlist_create")).thenReturn(false);

        assertThrows(UnauthorizedException.class, () -> {
            playlistController.createPlaylist(userDetails, req);
        });

        verify(playlistService, never()).createPlaylist(any(), any());
    }

    @Test
    void createPlaylist_whenPremiumUser_shouldSucceed() {
        CreatePlaylistRequest req = new CreatePlaylistRequest();
        req.setName("Summer Hits");

        PlaylistDto created = new PlaylistDto();
        created.setName("Summer Hits");

        when(subscriptionService.isFeatureAllowed(userId, "playlist_create")).thenReturn(true);
        when(playlistService.createPlaylist(userId, req)).thenReturn(created);

        ResponseEntity<PlaylistDto> response = playlistController.createPlaylist(userDetails, req);

        assertEquals(201, response.getStatusCode().value());
        assertEquals("Summer Hits", response.getBody().getName());
        verify(playlistService).createPlaylist(userId, req);
    }
}
