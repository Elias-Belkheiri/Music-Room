package com.musicroom.musicroom.entity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    @Column(name = "avatar_url", columnDefinition = "TEXT")
    private String avatarUrl;

    @Column(name = "auth_provider", nullable = false)
    private String authProvider = "local";

    @Column(name = "provider_id")
    private String providerId;

    @Column(name = "email_verified")
    private boolean emailVerified = false;

    @Column(name = "verification_code", length = 6)
    private String verificationCode;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "public_info", columnDefinition = "jsonb")
    private Map<String, Object> publicInfo;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "friends_info", columnDefinition = "jsonb")
    private Map<String, Object> friendsInfo;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "private_info", columnDefinition = "jsonb")
    private Map<String, Object> privateInfo;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "music_preferences", columnDefinition = "jsonb")
    private Map<String, Object> musicPreferences;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    @Builder.Default
    @Column(name = "subscription_tier", nullable = false)
    private String subscriptionTier = "free";

    @Column(name = "subscription_started_at")
    private LocalDateTime subscriptionStartedAt;

    @Column(name = "subscription_expires_at")
    private LocalDateTime subscriptionExpiresAt;

    public boolean isPremium() {
        return "premium".equals(subscriptionTier)
            && subscriptionExpiresAt != null
            && subscriptionExpiresAt.isAfter(LocalDateTime.now());
    }

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<RefreshToken> refreshTokens = new ArrayList<>();
}
