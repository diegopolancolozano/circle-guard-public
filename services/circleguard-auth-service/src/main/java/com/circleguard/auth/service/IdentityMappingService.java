package com.circleguard.auth.service;

import com.circleguard.auth.config.IdentityFeatureProperties;
import com.circleguard.auth.identity.LocalIdentityMappingStrategy;
import com.circleguard.auth.identity.RemoteIdentityMappingStrategy;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class IdentityMappingService {
    private final IdentityFeatureProperties featureProperties;
    private final RemoteIdentityMappingStrategy remoteStrategy;
    private final LocalIdentityMappingStrategy localStrategy;

    public UUID resolveAnonymousId(String realIdentity) {
        if (featureProperties.isUseRemote()) {
            return remoteStrategy.resolveAnonymousId(realIdentity);
        }
        return localStrategy.resolveAnonymousId(realIdentity);
    }
}
