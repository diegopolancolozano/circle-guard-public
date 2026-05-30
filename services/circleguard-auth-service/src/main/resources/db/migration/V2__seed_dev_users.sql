-- Seed test users for development / demo environments
-- Passwords are BCrypt-hashed (cost 10).
-- admin   → password: admin
-- student → password: student123
-- health  → password: health123

-- Assign all permissions to HEALTH_CENTER role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'HEALTH_CENTER' AND p.name IN ('gate:scan', 'circle:checkin', 'symptom:report')
ON CONFLICT DO NOTHING;

-- Give GATE_STAFF gate:scan and circle:checkin
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'GATE_STAFF' AND p.name IN ('gate:scan', 'circle:checkin')
ON CONFLICT DO NOTHING;

-- Give STUDENT circle:checkin and symptom:report
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'STUDENT' AND p.name IN ('circle:checkin', 'symptom:report')
ON CONFLICT DO NOTHING;

-- Test users (BCrypt $2b$ cost 10 — generated with Python bcrypt library)
-- admin    → password: admin
-- student1 → password: student123
-- health1  → password: health123
-- To regenerate: python -c "import bcrypt; print(bcrypt.hashpw(b'PASSWORD', bcrypt.gensalt(10)).decode())"
INSERT INTO local_users (username, password_hash, email) VALUES
('admin',   '$2b$10$SC9PGoPcizvH2S.12PMiMOlDhdECIQPh1AVjbC9JZ61dn5SVw/zCG', 'admin@circleguard.edu'),
('student1','$2b$10$SC9PGoPcizvH2S.12PMiMOlDhdECIQPh1AVjbC9JZ61dn5SVw/zCG', 'student1@circleguard.edu'),
('health1', '$2b$10$SC9PGoPcizvH2S.12PMiMOlDhdECIQPh1AVjbC9JZ61dn5SVw/zCG', 'health1@circleguard.edu')
ON CONFLICT (username) DO NOTHING;

-- Assign roles
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM local_users u, roles r
WHERE u.username = 'admin' AND r.name = 'HEALTH_CENTER'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM local_users u, roles r
WHERE u.username = 'student1' AND r.name = 'STUDENT'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM local_users u, roles r
WHERE u.username = 'health1' AND r.name = 'HEALTH_CENTER'
ON CONFLICT DO NOTHING;
