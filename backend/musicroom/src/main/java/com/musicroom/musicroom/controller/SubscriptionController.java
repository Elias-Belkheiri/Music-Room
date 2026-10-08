package com.musicroom.musicroom.controller;

import com.musicroom.musicroom.dto.SubscriptionRequestDto;
import com.musicroom.musicroom.service.SubscriptionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/subscription")
@RequiredArgsConstructor
@Tag(name = "Subscription", description = "User subscription management")
public class SubscriptionController {

    private final SubscriptionService subscriptionService;

    @Operation(summary = "Get subscription status")
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus(@AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return ResponseEntity.ok(subscriptionService.getSubscriptionStatus(userId));
    }

    @Operation(summary = "Upgrade to premium")
    @PostMapping("/upgrade")
    public ResponseEntity<Map<String, Object>> upgrade(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody SubscriptionRequestDto request) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        subscriptionService.upgradeToPremium(userId, request.getDuration());
        return ResponseEntity.ok(subscriptionService.getSubscriptionStatus(userId));
    }

    @Operation(summary = "Downgrade to free")
    @PostMapping("/downgrade")
    public ResponseEntity<Map<String, Object>> downgrade(@AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        subscriptionService.downgradeToFree(userId);
        return ResponseEntity.ok(subscriptionService.getSubscriptionStatus(userId));
    }

    @Operation(summary = "Get available plans")
    @GetMapping("/plans")
    public ResponseEntity<List<Map<String, Object>>> getPlans() {
        return ResponseEntity.ok(List.of(
            Map.of(
                "tier", "free",
                "price", 0,
                "duration", "lifetime"
            ),
            Map.of(
                "tier", "premium",
                "price", 9.99,
                "duration", "monthly"
            ),
            Map.of(
                "tier", "premium",
                "price", 99.99,
                "duration", "yearly"
            )
        ));
    }
}
