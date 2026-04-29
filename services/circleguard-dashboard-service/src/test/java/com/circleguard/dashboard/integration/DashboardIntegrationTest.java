package com.circleguard.dashboard.integration;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.*;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class DashboardIntegrationTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private com.circleguard.dashboard.service.AnalyticsService analyticsService;

    @Test
    void healthBoardEndpointReturnsAggregates() throws Exception {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalGreen", 1000);
        stats.put("totalExposed", 10);

        when(analyticsService.getGlobalHealthStats()).thenReturn(stats);

        mvc.perform(get("/api/v1/analytics/health-board"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalGreen").value(1000))
                .andExpect(jsonPath("$.totalExposed").value(10));
    }
}
