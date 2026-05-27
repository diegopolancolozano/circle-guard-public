package com.circleguard.auth.identity;

import org.springframework.stereotype.Component;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

@Component
public class LocalIdentityMappingStrategy implements IdentityMappingStrategy {
    @Override
    public UUID resolveAnonymousId(String realIdentity) {
        String input = "circleguard:" + realIdentity;
        return UUID.nameUUIDFromBytes(input.getBytes(StandardCharsets.UTF_8));
    }

    @Override
    public String name() {
        return "local";
    }
}
