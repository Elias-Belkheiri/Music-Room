package com.musicroom.musicroom.service;

import com.musicroom.musicroom.entity.User;
import java.util.Map;
import java.util.UUID;

public interface SubscriptionService {
    User upgradeToPremium(UUID userId, String duration);
    User downgradeToFree(UUID userId);
    boolean isFeatureAllowed(UUID userId, String feature);
    Map<String, Object> getSubscriptionStatus(UUID userId);
}
