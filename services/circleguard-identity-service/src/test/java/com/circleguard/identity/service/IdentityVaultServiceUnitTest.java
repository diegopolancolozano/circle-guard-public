package com.circleguard.identity.service;

import com.circleguard.identity.model.IdentityMapping;
import com.circleguard.identity.repository.IdentityMappingRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class IdentityVaultServiceUnitTest {

    private IdentityMappingRepository repository;
    private IdentityVaultService service;

    @BeforeEach
    void setUp() {
        repository = Mockito.mock(IdentityMappingRepository.class);
        service = new IdentityVaultService(repository);
    }

    @Test
    void whenMappingExists_thenReturnExistingAnonymousId() {
        String real = "existing-user";
        UUID existingId = UUID.randomUUID();
        IdentityMapping mapping = IdentityMapping.builder()
                .anonymousId(existingId)
                .realIdentity(real)
                .identityHash("abc")
                .salt("salt")
                .build();

        when(repository.findByIdentityHash(anyString())).thenReturn(Optional.of(mapping));

        UUID result = service.getOrCreateAnonymousId(real);

        assertEquals(existingId, result);
        verify(repository, never()).save(any());
    }

    @Test
    void whenMappingMissing_thenCreateAndReturnNewAnonymousId() {
        String real = "new-user";
        when(repository.findByIdentityHash(anyString())).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(invocation -> {
            IdentityMapping mapping = invocation.getArgument(0);
            ReflectionTestUtils.setField(mapping, "anonymousId", UUID.randomUUID());
            return mapping;
        });

        UUID result = service.getOrCreateAnonymousId(real);

        assertNotNull(result);
        verify(repository).save(any(IdentityMapping.class));
    }
}
