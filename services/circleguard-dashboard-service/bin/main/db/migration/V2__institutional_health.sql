-- Tabla agregada de salud institucional (PoC: datos de demo)
CREATE TABLE IF NOT EXISTS institutional_health (
    id         SERIAL PRIMARY KEY,
    status     VARCHAR(20) NOT NULL,
    location   VARCHAR(100),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Datos semilla para la demo (idempotente: sólo inserta si la tabla está vacía)
INSERT INTO institutional_health (status, location)
SELECT v.status, v.location FROM (VALUES
    ('GREEN',  'Bloque A - Aula 101'),
    ('GREEN',  'Bloque A - Aula 102'),
    ('GREEN',  'Bloque B - Laboratorio'),
    ('GREEN',  'Biblioteca'),
    ('RED',    'Bloque C - Aula 301'),
    ('GREEN',  'Cafetería'),
    ('GREEN',  'Sala de Reuniones'),
    ('RED',    'Gimnasio'),
    ('GREEN',  'Auditorio'),
    ('GREEN',  'Oficinas Administrativas')
) AS v(status, location)
WHERE NOT EXISTS (SELECT 1 FROM institutional_health LIMIT 1);
