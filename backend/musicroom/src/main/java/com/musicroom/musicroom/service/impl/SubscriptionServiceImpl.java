package com.musicroom.musicroom.service.impl;

import com.musicroom.musicroom.entity.User;
import com.musicroom.musicroom.exception.ResourceNotFoundException;
import com.musicroom.musicroom.repository.UserRepository;
import com.musicroom.musicroom.service.SubscriptionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SubscriptionServiceImpl implements SubscriptionService {

    private final UserRepository userRepository;

    @Override
    @Transactional
    public User upgradeToPremium(UUID userId, String duration) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        
        user.setSubscriptionTier("premium");
        user.setSubscriptionStartedAt(LocalDateTime.now());
        
        if ("yearly".equalsIgnoreCase(duration)) {
            user.setSubscriptionExpiresAt(LocalDateTime.now().plusYears(1));
        } else {
            user.setSubscriptionExpiresAt(LocalDateTime.now().plusMonths(1));
        }
        
        return userRepository.save(user);
    }

    @Override
    @Transactional
    public User downgradeToFree(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
                
        user.setSubscriptionTier("free");
        user.setSubscriptionStartedAt(null);
        user.setSubscriptionExpiresAt(null);
        
        return userRepository.save(user);
    }

    @Override
    public boolean isFeatureAllowed(UUID userId, String feature) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
                
        if (user.isPremium()) {
            return true; // Premium users can access all features
        }
        
        // Free users are restricted from premium features
        return switch (feature) {
            case "playlist_create", "playlist_edit", "playlist_invite" -> false;
            default -> true;
        };
    }

    @Override
    public Map<String, Object> getSubscriptionStatus(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
                
        Map<String, Object> status = new HashMap<>();
        status.put("tier", user.getSubscriptionTier());
        status.put("isPremium", user.isPremium());
        status.put("startedAt", user.getSubscriptionStartedAt());
        status.put("expiresAt", user.getSubscriptionExpiresAt());
        
        return status;
    }
}
