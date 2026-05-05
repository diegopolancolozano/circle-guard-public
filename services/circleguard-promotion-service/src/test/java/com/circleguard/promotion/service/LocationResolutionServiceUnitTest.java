package com.circleguard.promotion.service;

import com.circleguard.promotion.model.AccessPoint;
import com.circleguard.promotion.repository.AccessPointRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.kafka.core.KafkaTemplate;

import static org.mockito.Mockito.*;

class LocationResolutionServiceUnitTest {

    private LocationResolutionService svc;
    private AccessPointRepository accessPointRepository;
    private MacSessionRegistry sessionRegistry;
    private GraphService graphService;
    private KafkaTemplate<String, Object> kafkaTemplate;
    private StringRedisTemplate redisTemplate;

    @BeforeEach
    void setUp() {
        accessPointRepository = Mockito.mock(AccessPointRepository.class);
        sessionRegistry = Mockito.mock(MacSessionRegistry.class);
        graphService = Mockito.mock(GraphService.class);
        kafkaTemplate = Mockito.mock(KafkaTemplate.class);
        redisTemplate = Mockito.mock(StringRedisTemplate.class);

        svc = new LocationResolutionService(accessPointRepository, sessionRegistry, graphService, kafkaTemplate, redisTemplate);
    }

    @Test
    void whenUnknownAp_thenIgnore() {
        when(accessPointRepository.findByMacAddress("unknown")).thenReturn(java.util.Optional.empty());
        svc.processSignal("unknown", "device-mac", -50.0);
        verify(kafkaTemplate, never()).send(anyString(), anyString(), any());
    }

    @Test
    void whenSessionMissing_thenMonitorOnly() {
        AccessPoint ap = new AccessPoint();
        ap.setId(java.util.UUID.randomUUID());
        ap.setName("AP1");
        when(accessPointRepository.findByMacAddress("apmac")).thenReturn(java.util.Optional.of(ap));
        when(sessionRegistry.getAnonymousId("device-mac")).thenReturn(null);

        svc.processSignal("apmac", "device-mac", -40.0);
        verify(kafkaTemplate, never()).send(anyString(), anyString(), any());
    }
}
