package com.musicroom.musicroom.service;

import com.musicroom.musicroom.dto.EventDto;
import com.musicroom.musicroom.entity.Event;
import com.musicroom.musicroom.entity.User;
import com.musicroom.musicroom.repository.EventRepository;
import com.musicroom.musicroom.service.impl.EventServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EventNearbyTests {

    @Mock
    private EventRepository eventRepo;

    @Mock
    private PlaybackService playbackService;

    private EventServiceImpl eventService;

    @BeforeEach
    void setUp() {
        eventService = new EventServiceImpl(
                eventRepo,
                null,
                null,
                null,
                null,
                null,
                null,
                playbackService
        );
    }

    private Event createPublicEvent(String name, double lat, double lng) {
        User owner = new User();
        owner.setId(UUID.randomUUID());
        owner.setDisplayName("Host");

        Event event = new Event();
        event.setId(UUID.randomUUID());
        event.setName(name);
        event.setVisibility("public");
        event.setActive(true);
        event.setLatitude(lat);
        event.setLongitude(lng);
        event.setOwner(owner);
        return event;
    }

    @Test
    void getNearbyEvents_shouldFilterByRadiusAndSortByDistance() {
        // Paris center: 48.8566, 2.3522
        // Close event (~1.5 km away): 48.8600, 2.3400
        Event closeEvent = createPublicEvent("Close Venue", 48.8600, 2.3400);

        // Very close event (~500 m away): 48.8570, 2.3500
        Event veryCloseEvent = createPublicEvent("Immediate Venue", 48.8570, 2.3500);

        // Far event (London ~340 km away): 51.5074, -0.1278
        Event farEvent = createPublicEvent("Far Venue", 51.5074, -0.1278);

        when(eventRepo.findByVisibilityAndActiveTrue("public"))
                .thenReturn(List.of(closeEvent, farEvent, veryCloseEvent));

        // Scan within 5 km radius
        List<EventDto> nearby = eventService.getNearbyEvents(48.8566, 2.3522, 5.0);

        assertEquals(2, nearby.size());
        // Immediate Venue must be first (sorted by distance ascending)
        assertEquals("Immediate Venue", nearby.get(0).getName());
        assertEquals("Close Venue", nearby.get(1).getName());
    }

    @Test
    void getNearbyEvents_whenOutsideRadius_shouldReturnEmpty() {
        Event farEvent = createPublicEvent("Far Venue", 51.5074, -0.1278);
        when(eventRepo.findByVisibilityAndActiveTrue("public"))
                .thenReturn(List.of(farEvent));

        // Search with 1 km radius around Paris
        List<EventDto> nearby = eventService.getNearbyEvents(48.8566, 2.3522, 1.0);

        assertEquals(0, nearby.size());
    }
}
