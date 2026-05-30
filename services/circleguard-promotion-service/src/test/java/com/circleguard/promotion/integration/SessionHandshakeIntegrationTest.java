package com.circleguard.promotion.integration;

import com.circleguard.promotion.service.MacSessionRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import com.circleguard.promotion.controller.SessionHandshakeController;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SessionHandshakeController.class)
class SessionHandshakeIntegrationTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private MacSessionRegistry sessionRegistry;

    @Test
    void handshake_shouldRegisterSessionAndReturnOk() throws Exception {
        mvc.perform(post("/api/v1/sessions/handshake")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"macAddress\":\"AA:BB:CC:DD:EE:01\",\"anonymousId\":\"anon-123\"}"))
                .andExpect(status().isOk());

        verify(sessionRegistry).registerSession("AA:BB:CC:DD:EE:01", "anon-123");
    }

    @Test
    void handshake_shouldReturnBadRequestWhenPayloadIsIncomplete() throws Exception {
        mvc.perform(post("/api/v1/sessions/handshake")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"macAddress\":\"AA:BB:CC:DD:EE:01\"}"))
                .andExpect(status().isBadRequest());

        verify(sessionRegistry, never()).registerSession(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString());
    }
}
