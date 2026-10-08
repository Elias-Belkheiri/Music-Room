package com.musicroom.musicroom.service;

import com.musicroom.musicroom.entity.User;
import com.musicroom.musicroom.repository.UserRepository;
import com.musicroom.musicroom.service.impl.SubscriptionServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SubscriptionServiceImplTest {

    @Mock
    private UserRepository userRepository;

    private SubscriptionServiceImpl subscriptionService;

    private User testUser;
    private UUID userId;

    @BeforeEach
    void setUp() {
        subscriptionService = new SubscriptionServiceImpl(userRepository);
        userId = UUID.randomUUID();
        testUser = User.builder()
                .email("user@example.com")
                .displayName("Test User")
                .subscriptionTier("free")
                .build();
        testUser.setId(userId);
    }

    @Test
    void upgradeToPremium_monthly_shouldSetDatesAndTier() {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));

        User updated = subscriptionService.upgradeToPremium(userId, "monthly");

        assertEquals("premium", updated.getSubscriptionTier());
        assertNotNull(updated.getSubscriptionStartedAt());
        assertNotNull(updated.getSubscriptionExpiresAt());
        assertTrue(updated.getSubscriptionExpiresAt().isAfter(LocalDateTime.now()));
        assertTrue(updated.isPremium());
        verify(userRepository).save(testUser);
    }

    @Test
    void upgradeToPremium_yearly_shouldSetOneYearExpiry() {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));

        User updated = subscriptionService.upgradeToPremium(userId, "yearly");

        assertEquals("premium", updated.getSubscriptionTier());
        assertTrue(updated.getSubscriptionExpiresAt().isAfter(LocalDateTime.now().plusMonths(11)));
        assertTrue(updated.isPremium());
    }

    @Test
    void downgradeToFree_shouldResetTierAndDates() {
        testUser.setSubscriptionTier("premium");
        testUser.setSubscriptionStartedAt(LocalDateTime.now());
        testUser.setSubscriptionExpiresAt(LocalDateTime.now().plusMonths(1));

        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));

        User updated = subscriptionService.downgradeToFree(userId);

        assertEquals("free", updated.getSubscriptionTier());
        assertNull(updated.getSubscriptionStartedAt());
        assertNull(updated.getSubscriptionExpiresAt());
        assertFalse(updated.isPremium());
    }

    @Test
    void isFeatureAllowed_whenFree_shouldBlockRestrictedFeatures() {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));

        assertFalse(subscriptionService.isFeatureAllowed(userId, "playlist_create"));
        assertFalse(subscriptionService.isFeatureAllowed(userId, "playlist_edit"));
        assertFalse(subscriptionService.isFeatureAllowed(userId, "playlist_invite"));
        assertTrue(subscriptionService.isFeatureAllowed(userId, "event_join"));
        assertTrue(subscriptionService.isFeatureAllowed(userId, "track_vote"));
    }

    @Test
    void isFeatureAllowed_whenPremium_shouldAllowAllFeatures() {
        testUser.setSubscriptionTier("premium");
        testUser.setSubscriptionExpiresAt(LocalDateTime.now().plusDays(10));

        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));

        assertTrue(subscriptionService.isFeatureAllowed(userId, "playlist_create"));
        assertTrue(subscriptionService.isFeatureAllowed(userId, "playlist_edit"));
        assertTrue(subscriptionService.isFeatureAllowed(userId, "playlist_invite"));
        assertTrue(subscriptionService.isFeatureAllowed(userId, "event_join"));
    }

    @Test
    void getSubscriptionStatus_shouldReturnProperMetadata() {
        testUser.setSubscriptionTier("free");
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));

        Map<String, Object> status = subscriptionService.getSubscriptionStatus(userId);

        assertEquals("free", status.get("tier"));
        assertEquals(false, status.get("isPremium"));
        assertNull(status.get("expiresAt"));
    }
}
