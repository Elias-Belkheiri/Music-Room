package com.musicroom.musicroom.service.impl;

import java.security.SecureRandom;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.musicroom.musicroom.dto.AuthResponse;
import com.musicroom.musicroom.dto.*;
import com.musicroom.musicroom.dto.ResetPassword;
import com.musicroom.musicroom.entity.RefreshToken;
import com.musicroom.musicroom.entity.User;
import com.musicroom.musicroom.repository.UserRepository;
import com.musicroom.musicroom.security.JwtTokenProvider;
import com.musicroom.musicroom.service.AuthService;
import com.musicroom.musicroom.service.EmailService;
import com.musicroom.musicroom.service.LogService;
import com.musicroom.musicroom.service.DeviceService;
import com.musicroom.musicroom.service.RefreshTokenService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenService refreshTokenService;
    private final EmailService emailService;
    private final LogService logService;
    private final DeviceService deviceService;

    /**
     * Normalizes an email for storage and lookup.
     * Beyond trim + lowercase this also strips invisible characters that
     * mobile autofill/keyboards can inject (zero-width spaces, BOM,
     * non-breaking spaces via NFKC) — String.trim() leaves those behind
     * and they silently break exact-match lookups.
     */
    private String normalizeEmail(String email) {
        if (email == null) {
            return null;
        }
        String s = java.text.Normalizer.normalize(email, java.text.Normalizer.Form.NFKC);
        s = s.replaceAll("[\\p{Cc}\\p{Cf}]", "");
        return s.strip().toLowerCase(java.util.Locale.ROOT);
    }

    /**
     * Helper method to extract real client IP address
     */
    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }
        
        return request.getRemoteAddr();
    }

    @Override
    public AuthResponse register(RegisterRequestDTO request, HttpServletRequest httpRequest) {
        try {
                String email = normalizeEmail(request.email());
                if (userRepository.existsByEmailIgnoreCase(email)) {
                throw new RuntimeException("Email already exists");
                } else if (request.password().length() < 6) {
                throw new RuntimeException("Password must be at least 6 characters");
                }

                SecureRandom secureRandom = new SecureRandom();
                String verificationCode = String.format("%06d", secureRandom.nextInt(1000000));
                User user = User.builder()
                        .email(email)
                        .passwordHash(passwordEncoder.encode(request.password()))
                        .displayName(request.displayname())
                        .authProvider("local")
                        .build();
        
                user.setVerificationCode(verificationCode);

                User savedUser = userRepository.save(user);
                emailService.sendVerificationEmail(email, verificationCode);

                String ipAddress = getClientIpAddress(httpRequest);

                // Log user registration
                logService.logUserRegister(savedUser.getId(), email, "web", ipAddress);
                
                String accessToken = jwtTokenProvider.generateAccessToken(
                        savedUser.getEmail(),
                        savedUser.getId().toString()
                );

                String refreshToken = refreshTokenService.createRefreshToken(savedUser);

                return new AuthResponse(
                        accessToken,
                        refreshToken,
                        "Bearer",
                        jwtTokenProvider.getAccessTokenExpiration(),
                        new RegisterResponseDTO(
                                savedUser.getId(),
                                savedUser.getEmail(),
                                savedUser.getDisplayName(),
                                savedUser.getAvatarUrl(),
                                String.valueOf(savedUser.isEmailVerified())
                        )
                );
        } catch (Exception e) {
                throw new RuntimeException("Registration failed: " + e.getMessage());
        }
    }

    @Override
    public AuthResponse login(LoginRequestDTO request, HttpServletRequest httpRequest) {

        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(request.email()))
                .orElseThrow(() -> new RuntimeException("Email does not exist"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new RuntimeException("Invalid credentials");
        }
        
        String ipAddress = getClientIpAddress(httpRequest);
        
        // Register or update device when user logs in
        deviceService.registerOrUpdateDevice(
            user.getId(),
            request.deviceName() != null ? request.deviceName() : "Web Browser",
            request.platform() != null ? request.platform() : "Web",
            request.appVersion() != null ? request.appVersion() : "1.0.0",
            ipAddress
        );
        
        String accessToken = jwtTokenProvider.generateAccessToken(
                user.getEmail(),
                user.getId().toString()
        );

        String refreshToken = refreshTokenService.createRefreshToken(user);
        
        // Log user login
        logService.logUserLogin(user.getId(), request.platform() != null ? request.platform() : "Web", ipAddress);
        
        return new AuthResponse(
                accessToken,
                refreshToken,
                "Bearer",
                jwtTokenProvider.getAccessTokenExpiration(),
                new RegisterResponseDTO(
                        user.getId(),
                        user.getEmail(),
                        user.getDisplayName(),
                        user.getAvatarUrl(),
                        String.valueOf(user.isEmailVerified())
                )
        );
    }

    @Override
    @Transactional
    public TokenRefreshResponseDTO refreshAccessToken(TokenRefreshRequestDTO request) {
        // Verify refresh token is valid and not revoked
        RefreshToken refreshToken = refreshTokenService.verifyRefreshToken(request.refreshToken())
                .orElseThrow(() -> new RuntimeException("Invalid or expired refresh token"));

        User user = refreshToken.getUser();

        String accessToken = jwtTokenProvider.generateAccessToken(
                user.getEmail(),
                user.getId().toString()
        );

        return new TokenRefreshResponseDTO(
                accessToken,
                request.refreshToken(),
                "Bearer",
                jwtTokenProvider.getAccessTokenExpiration()
        );
    }

    @Override
    public TokenRefreshResponseDTO refreshToken(TokenRefreshRequestDTO request) {
        return refreshAccessToken(request);
    }

    // Generate and send verification code
    @Override
     public String sendVerificationEmail(SendVerificationEmailDTO request, HttpServletRequest httpRequest) {
        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(request.email()))
                .orElseThrow(() -> new RuntimeException("Email does not exist"));

        SecureRandom secureRandom = new SecureRandom();
        String verificationCode = String.format("%06d", secureRandom.nextInt(1000000));

        user.setVerificationCode(verificationCode);
        userRepository.save(user);

        try {
            // SEND EMAIL
            emailService.sendVerificationEmail(request.email(), verificationCode);
            
            String ipAddress = getClientIpAddress(httpRequest);
            
            // Log verification email sent
            logService.saveLog(user.getId(), null, "VERIFICATION_EMAIL_SENT", "web", null, ipAddress,
                    java.util.Map.of("email", request.email(), "timestamp", java.time.LocalDateTime.now().toString()));
        } catch (Exception e) {
            throw new RuntimeException("Failed to send verification email: " + e.getMessage());
        }
        return "Verification email sent successfully";
    }

    // Verify email with code
    @Override
    public String verifyEmail(VerifyEmailDTO request, HttpServletRequest httpRequest) {
        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(request.email()))
                .orElseThrow(() -> new RuntimeException("Email does not exist"));

        if (user.getVerificationCode() == null || !user.getVerificationCode().equals(request.verificationCode())) {
            throw new RuntimeException("Invalid verification code");
        }

        user.setEmailVerified(true);
        user.setVerificationCode(null);
        userRepository.save(user);
        
        String ipAddress = getClientIpAddress(httpRequest);
        
        // Log email verification
        logService.saveLog(user.getId(), null, "EMAIL_VERIFIED", "web", null, ipAddress, 
                java.util.Map.of("email", request.email(), "timestamp", java.time.LocalDateTime.now().toString()));

        return "Email verified successfully";
    }

    @Override
     public String verifyEmailPassReset(VerifyEmailDTO request, HttpServletRequest httpRequest) {
        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(request.email()))
                .orElseThrow(() -> new RuntimeException("Email does not exist"));

        if (user.getVerificationCode() == null || !user.getVerificationCode().equals(request.verificationCode())) {
            throw new RuntimeException("Invalid verification code");
        }
        
        String ipAddress = getClientIpAddress(httpRequest);
        
        // Log password reset verification
        logService.saveLog(user.getId(), null, "PASSWORD_RESET_VERIFIED", "web", null, ipAddress,
                java.util.Map.of("email", request.email(), "timestamp", java.time.LocalDateTime.now().toString()));

        return "Code verified successfully";
    }

    @Override
    public String PassResetChange(ResetPassword request, HttpServletRequest httpRequest) {
        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(request.email()))
                .orElseThrow(() -> new RuntimeException("Email does not exist"));

        if (user.getVerificationCode() == null || !user.getVerificationCode().equals(request.verificationCode())) {
            throw new RuntimeException("Invalid verification code");
        }

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);
        
        String ipAddress = getClientIpAddress(httpRequest);
        
        // Log password reset
        logService.saveLog(user.getId(), null, "PASSWORD_RESET", "web", null, ipAddress,
                java.util.Map.of("email", request.email(), "timestamp", java.time.LocalDateTime.now().toString()));

        return "Password reset successfully";
    }

    @Override
    public AuthResponse googleLogin(String email, String name, String googleId, HttpServletRequest httpRequest) {
        // Check if user exists
        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(email))
                .orElseGet(() -> {
                    // Create new user if doesn't exist
                    User newUser = User.builder()
                            .email(normalizeEmail(email))
                            .displayName(name)
                            .authProvider("google")
                            .providerId(googleId)
                            .emailVerified(true)  // Google email is already verified
                            .passwordHash(null)  // No password for Google users
                            .build();
                    return userRepository.save(newUser);
                });

        // Generate tokens
        String accessToken = jwtTokenProvider.generateAccessToken(
                user.getEmail(),
                user.getId().toString()
        );

        String refreshToken = refreshTokenService.createRefreshToken(user);
        
        String ipAddress = getClientIpAddress(httpRequest);
        
        // Log Google login
        logService.logUserLogin(user.getId(), "web", ipAddress);

        return new AuthResponse(
                accessToken,
                refreshToken,
                "Bearer",
                jwtTokenProvider.getAccessTokenExpiration(),
                new RegisterResponseDTO(
                        user.getId(),
                        user.getEmail(),
                        user.getDisplayName(),
                        user.getAvatarUrl(),
                        String.valueOf(user.isEmailVerified())
                )
        );
    }

    @Override
    @SuppressWarnings("unchecked")
    public AuthResponse googleLoginWithToken(String idToken, HttpServletRequest httpRequest) {
        try {
            // Decode the JWT token
            String[] parts = idToken.split("\\.");
            if (parts.length != 3) {
                throw new RuntimeException("Invalid token format");
            }
            
            // Decode payload (2nd part)
            String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
            
            // Parse JSON
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            java.util.Map<String, Object> tokenData = mapper.readValue(payload, java.util.Map.class);
            
            String email = (String) tokenData.get("email");
            String name = (String) tokenData.get("name");
            String googleId = (String) tokenData.get("sub");

            if (email == null || name == null || googleId == null) {
                throw new RuntimeException("Invalid token: missing email, name, or googleId");
            }

            return googleLogin(email, name, googleId, httpRequest);

        } catch (Exception e) {
            throw new RuntimeException("Google login failed: " + e.getMessage());
        }
    }
}
