package com.circleguard.auth.identity;

import com.circleguard.auth.client.IdentityClient;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RemoteIdentityMappingStrategyTest {

    @Mock
    private IdentityClient identityClient;
    @Mock
    private LocalIdentityMappingStrategy localStrategy;
    @InjectMocks
    private RemoteIdentityMappingStrategy strategy;

    @Test
    void delegatesToIdentityClientWhenAvailable() {
        UUID expected = UUID.randomUUID();
        when(identityClient.getAnonymousId("user@test.com")).thenReturn(expected);

        UUID result = strategy.resolveAnonymousId("user@test.com");

        assertThat(result).isEqualTo(expected);
        verify(identityClient).getAnonymousId("user@test.com");
    }

    @Test
    void nameIsRemote() {
        assertThat(strategy.name()).isEqualTo("remote");
    }

    @Test
    void fallback_delegatesToLocalStrategyWhenRemoteFails() {
        UUID localId = UUID.randomUUID();
        RuntimeException networkError = new RuntimeException("identity service unavailable");
        when(localStrategy.resolveAnonymousId("user@test.com")).thenReturn(localId);

        UUID result = strategy.fallback("user@test.com", networkError);

        assertThat(result).isEqualTo(localId);
        verify(localStrategy).resolveAnonymousId("user@test.com");
        verifyNoInteractions(identityClient);
    }
}
