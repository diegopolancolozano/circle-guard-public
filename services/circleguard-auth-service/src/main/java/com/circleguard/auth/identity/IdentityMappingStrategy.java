package com.circleguard.auth.identity;

import java.util.UUID;

public interface IdentityMappingStrategy {
    UUID resolveAnonymousId(String realIdentity);
    String name();
}
