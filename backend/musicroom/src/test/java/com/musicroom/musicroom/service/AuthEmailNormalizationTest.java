package com.musicroom.musicroom.service;

import com.musicroom.musicroom.dto.LoginRequestDTO;
import com.musicroom.musicroom.entity.User;
import com.musicroom.musicroom.repository.UserRepository;
import com.musicroom.musicroom.security.JwtTokenProvider;
import com.musicroom.musicroom.service.impl.AuthServiceImpl;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.quality.Strictness;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * Regression tests for email normalization in the auth flow.
 * Mobile keyboards auto-capitalize and autofill can inject invisible
 * characters (zero-width spaces, NBSP) — login must accept all variants
 * of a stored address.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AuthEmailNormalizationTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private JwtTokenProvider jwtTokenProvider;
    @Mock
    private RefreshTokenService refreshTokenService;
    @Mock
    private EmailService emailService;
    @Mock
    private LogService logService;
    @Mock
    private DeviceService deviceService;
    @Mock
    private HttpServletRequest httpRequest;

    private AuthServiceImpl authService;

    @BeforeEach
    void setUp() {
        authService = new AuthServiceImpl(
                userRepository, passwordEncoder, jwtTokenProvider,
                refreshTokenService, emailService, logService, deviceService);

        User storedUser = User.builder()
                .email("user@example.com")
                .passwordHash("hashed")
                .displayName("User")
                .authProvider("local")
                .build();
        storedUser.setId(UUID.randomUUID());
        storedUser.setEmailVerified(true);

        when(userRepository.findByEmailIgnoreCase(eq("user@example.com")))
                .thenReturn(Optional.of(storedUser));
        when(passwordEncoder.matches(eq("secret123"), eq("hashed"))).thenReturn(true);
        when(jwtTokenProvider.generateAccessToken(any(), any())).thenReturn("access");
        when(refreshTokenService.createRefreshToken(any())).thenReturn("refresh");
        when(httpRequest.getHeader(any())).thenReturn(null);
        when(httpRequest.getRemoteAddr()).thenReturn("127.0.0.1");
    }

    private LoginRequestDTO loginAs(String email) {
        return new LoginRequestDTO(email, "secret123", "test", "test", "1.0.0");
    }

    @Test
    void login_withUppercaseEmail_shouldSucceed() {
        assertNotNull(authService.login(loginAs("USER@EXAMPLE.COM"), httpRequest));
    }

    @Test
    void login_withPaddedEmail_shouldSucceed() {
        assertNotNull(authService.login(loginAs("  user@example.com  "), httpRequest));
    }

    @Test
    void login_withZeroWidthSpace_shouldSucceed() {
        assertNotNull(authService.login(loginAs("us" + ((char) 0x200B) + "er@example.com"), httpRequest));
    }

    @Test
    void login_withNonBreakingSpace_shouldSucceed() {
        assertNotNull(authService.login(loginAs("user@example.com" + ((char) 0x00A0)), httpRequest));
    }

    @Test
    void login_withUnknownEmail_shouldThrow() {
        when(userRepository.findByEmailIgnoreCase(eq("nobody@example.com")))
                .thenReturn(Optional.empty());
        assertThrows(RuntimeException.class,
                () -> authService.login(loginAs("nobody@example.com"), httpRequest));
    }
}
