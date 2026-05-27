package com.circleguard.auth.service;

import com.circleguard.auth.config.IdentityFeatureProperties;
import com.circleguard.auth.identity.LocalIdentityMappingStrategy;
import com.circleguard.auth.identity.RemoteIdentityMappingStrategy;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class IdentityMappingServiceTest {

    @Mock
    private IdentityFeatureProperties featureProperties;
    @Mock
    private RemoteIdentityMappingStrategy remoteStrategy;
    @Mock
    private LocalIdentityMappingStrategy localStrategy;
    @InjectMocks
    private IdentityMappingService service;

    @Test
    void featureToggleEnabled_delegatesToRemoteStrategy() {
        UUID expected = UUID.randomUUID();
        when(featureProperties.isUseRemote()).thenReturn(true);
        when(remoteStrategy.resolveAnonymousId("user1")).thenReturn(expected);

        UUID result = service.resolveAnonymousId("user1");

        assertThat(result).isEqualTo(expected);
        verify(remoteStrategy).resolveAnonymousId("user1");
        verifyNoInteractions(localStrategy);
    }

    @Test
    void featureToggleDisabled_delegatesToLocalStrategy() {
        UUID expected = UUID.randomUUID();
        when(featureProperties.isUseRemote()).thenReturn(false);
        when(localStrategy.resolveAnonymousId("user1")).thenReturn(expected);

        UUID result = service.resolveAnonymousId("user1");

        assertThat(result).isEqualTo(expected);
        verify(localStrategy).resolveAnonymousId("user1");
        verifyNoInteractions(remoteStrategy);
    }
}
