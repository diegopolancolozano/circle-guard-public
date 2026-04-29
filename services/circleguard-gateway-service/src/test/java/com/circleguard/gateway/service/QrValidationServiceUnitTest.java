package com.circleguard.gateway.service;

import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.security.Key;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class QrValidationServiceUnitTest {

    private QrValidationService service;
    private StringRedisTemplate redisTemplate;
    private ValueOperations<String, String> valueOps;
    private final String secret = "my-super-secret-test-key-32-chars-long";

    @BeforeEach
    void setUp() {
        redisTemplate = Mockito.mock(StringRedisTemplate.class);
        valueOps = Mockito.mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOps);

        service = new QrValidationService(redisTemplate);
        org.springframework.test.util.ReflectionTestUtils.setField(service, "qrSecret", secret);
    }

    @Test
    void shouldRejectMalformedToken() {
        QrValidationService.ValidationResult result = service.validateToken("not-a-jwt");
        assertFalse(result.valid());
        assertEquals("RED", result.status());
    }

    @Test
    void shouldAllowWhenRedisMissingStatus() {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(secret.getBytes());
        String token = io.jsonwebtoken.Jwts.builder().setSubject(anonymousId).signWith(key).compact();

        when(valueOps.get("user:status:" + anonymousId)).thenReturn(null);

        QrValidationService.ValidationResult result = service.validateToken(token);
        assertTrue(result.valid());
        assertEquals("GREEN", result.status());
    }
}
