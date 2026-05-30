package com.circleguard.auth.identity;

import com.circleguard.auth.client.IdentityClient;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class RemoteIdentityMappingStrategy implements IdentityMappingStrategy {
    private final IdentityClient identityClient;
    private final LocalIdentityMappingStrategy localStrategy;

    @Override
    @CircuitBreaker(name = "identityClient", fallbackMethod = "fallback")
    public UUID resolveAnonymousId(String realIdentity) {
        return identityClient.getAnonymousId(realIdentity);
    }

    @Override
    public String name() {
        return "remote";
    }

    UUID fallback(String realIdentity, Throwable ex) {
        return localStrategy.resolveAnonymousId(realIdentity);
    }
}
