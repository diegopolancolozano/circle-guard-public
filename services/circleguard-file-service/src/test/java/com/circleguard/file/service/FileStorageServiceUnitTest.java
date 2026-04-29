package com.circleguard.file.service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

class FileStorageServiceUnitTest {

    @AfterEach
    void cleanup() throws Exception {
        Path uploads = Path.of("uploads");
        if (Files.exists(uploads)) {
            Files.walk(uploads)
                    .sorted(java.util.Comparator.reverseOrder())
                    .forEach(p -> p.toFile().delete());
        }
    }

    @Test
    void shouldSaveFileAndReturnFilename() throws Exception {
        FileStorageService svc = new FileStorageService();
        MockMultipartFile file = new MockMultipartFile("file", "test.txt", "text/plain", "hello".getBytes());

        String filename = svc.saveFile(file);

        assertNotNull(filename);
        assertTrue(Files.exists(Path.of("uploads").resolve(filename)));
    }
}
