package com.musicroom.musicroom.entity;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class UserBuilderTest {

    @Test
    void builderDefaultsSubscriptionTierToFree() {
        User user = User.builder()
                .email("new-user@example.com")
                .displayName("New User")
                .authProvider("local")
                .build();

        assertEquals("free", user.getSubscriptionTier());
    }
}
