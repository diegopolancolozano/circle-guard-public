package com.circleguard.auth.identity;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class LocalIdentityMappingStrategyTest {

    private final LocalIdentityMappingStrategy strategy = new LocalIdentityMappingStrategy();

    @Test
    void sameInputProducesSameUUID() {
        UUID first = strategy.resolveAnonymousId("alice@example.com");
        UUID second = strategy.resolveAnonymousId("alice@example.com");
        assertThat(first).isEqualTo(second);
    }

    @Test
    void differentInputsProduceDifferentUUIDs() {
        UUID alice = strategy.resolveAnonymousId("alice@example.com");
        UUID bob = strategy.resolveAnonymousId("bob@example.com");
        assertThat(alice).isNotEqualTo(bob);
    }

    @Test
    void nameIsLocal() {
        assertThat(strategy.name()).isEqualTo("local");
    }
}
