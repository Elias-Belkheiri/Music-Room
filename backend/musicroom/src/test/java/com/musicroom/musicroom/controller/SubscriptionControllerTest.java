package com.musicroom.musicroom.controller;

import com.musicroom.musicroom.dto.SubscriptionRequestDto;
import com.musicroom.musicroom.entity.User;
import com.musicroom.musicroom.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SubscriptionControllerTest {

    @Mock
    private SubscriptionService subscriptionService;

    @Mock
    private UserDetails userDetails;

    private SubscriptionController subscriptionController;
    private UUID userId;

    @BeforeEach
    void setUp() {
        subscriptionController = new SubscriptionController(subscriptionService);
        userId = UUID.randomUUID();
        when(userDetails.getUsername()).thenReturn(userId.toString());
    }

    @Test
    void getStatus_shouldReturnServiceStatus() {
        when(subscriptionService.getSubscriptionStatus(userId))
                .thenReturn(Map.of("tier", "free", "isPremium", false));

        ResponseEntity<Map<String, Object>> response = subscriptionController.getStatus(userDetails);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals("free", response.getBody().get("tier"));
        verify(subscriptionService).getSubscriptionStatus(userId);
    }

    @Test
    void upgrade_shouldCallServiceAndReturnStatus() {
        SubscriptionRequestDto dto = new SubscriptionRequestDto();
        dto.setDuration("monthly");
        dto.setTier("premium");

        when(subscriptionService.upgradeToPremium(userId, "monthly")).thenReturn(new User());
        when(subscriptionService.getSubscriptionStatus(userId))
                .thenReturn(Map.of("tier", "premium", "isPremium", true));

        ResponseEntity<Map<String, Object>> response = subscriptionController.upgrade(userDetails, dto);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(true, response.getBody().get("isPremium"));
        verify(subscriptionService).upgradeToPremium(userId, "monthly");
    }

    @Test
    void downgrade_shouldCallServiceAndReturnStatus() {
        when(subscriptionService.downgradeToFree(userId)).thenReturn(new User());
        when(subscriptionService.getSubscriptionStatus(userId))
                .thenReturn(Map.of("tier", "free", "isPremium", false));

        ResponseEntity<Map<String, Object>> response = subscriptionController.downgrade(userDetails);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(false, response.getBody().get("isPremium"));
        verify(subscriptionService).downgradeToFree(userId);
    }

    @Test
    void getPlans_shouldReturnAvailablePlansList() {
        ResponseEntity<List<Map<String, Object>>> response = subscriptionController.getPlans();

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(3, response.getBody().size());
    }
}
