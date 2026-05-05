package com.circleguard.dashboard.service;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;

class AnalyticsServiceUnitTest {

    @Test
    void shouldMaskSmallCountsForKAnonymity() {
        JdbcTemplate jdbc = Mockito.mock(JdbcTemplate.class);
        List<Map<String, Object>> rows = new ArrayList<>();
        Map<String, Object> r1 = new HashMap<>();
        r1.put("hour", "2026-04-29T08:00:00");
        r1.put("entry_count", 5L);
        rows.add(r1);

        doReturn(rows).when(jdbc).queryForList(anyString(), (Object[]) any());

        AnalyticsService svc = new AnalyticsService(jdbc);
        List<Map<String, Object>> result = svc.getEntryTrends(UUID.randomUUID());

        assertEquals(1, result.size());
        assertEquals(0, result.get(0).get("entry_count"));
        assertEquals("Insufficient data for privacy", result.get(0).get("note"));
    }
}
