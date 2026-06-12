-- Tabla agregada de salud institucional (PoC: datos de demo)
CREATE TABLE institutional_health (
    id         SERIAL PRIMARY KEY,
    status     VARCHAR(20) NOT NULL,
    location   VARCHAR(100),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Datos semilla para la demo
INSERT INTO institutional_health (status, location) VALUES
    ('GREEN',  'Bloque A - Aula 101'),
    ('GREEN',  'Bloque A - Aula 102'),
    ('GREEN',  'Bloque B - Laboratorio'),
    ('GREEN',  'Biblioteca'),
    ('RED',    'Bloque C - Aula 301'),
    ('GREEN',  'Cafetería'),
    ('GREEN',  'Sala de Reuniones'),
    ('RED',    'Gimnasio'),
    ('GREEN',  'Auditorio'),
    ('GREEN',  'Oficinas Administrativas');
