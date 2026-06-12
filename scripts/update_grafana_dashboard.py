#!/usr/bin/env python3
"""Update the CircleGuard Grafana dashboard with richer panels."""
import json
import urllib.request

import base64

GF_BASE = "http://138.197.228.70:3000"
_AUTH = "Basic " + base64.b64encode(b"admin:circleguard").decode()


def api(path, payload=None, method=None):
    data = json.dumps(payload).encode() if payload else None
    m = method or ("POST" if data else "GET")
    req = urllib.request.Request(
        f"{GF_BASE}{path}", data=data,
        headers={"Content-Type": "application/json", "Authorization": _AUTH},
        method=m,
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


PROM = {"type": "prometheus", "uid": "PBFA97CFB590B2093"}

dashboard = {
    "uid": "circleguard-live",
    "title": "CircleGuard Services (Live)",
    "tags": ["circleguard"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {"from": "now-30m", "to": "now"},
    "schemaVersion": 36,
    "panels": [

        # ── Row 1: Stats ─────────────────────────────────────────────────────
        {
            "id": 1, "type": "stat", "title": "Servicios UP",
            "gridPos": {"x": 0, "y": 0, "w": 4, "h": 4},
            "options": {
                "colorMode": "background", "graphMode": "none",
                "reduceOptions": {"calcs": ["lastNotNull"]},
                "textMode": "auto",
            },
            "fieldConfig": {
                "defaults": {
                    "thresholds": {"mode": "absolute", "steps": [
                        {"color": "red", "value": None},
                        {"color": "yellow", "value": 3},
                        {"color": "green", "value": 6},
                    ]},
                    "mappings": [],
                }
            },
            "targets": [{"datasource": PROM,
                         "expr": 'count(up{job="circleguard-services",namespace="stage"} == 1)',
                         "legendFormat": "up"}],
        },
        {
            "id": 2, "type": "stat", "title": "Pods Running",
            "gridPos": {"x": 4, "y": 0, "w": 4, "h": 4},
            "options": {"colorMode": "background", "graphMode": "none",
                        "reduceOptions": {"calcs": ["lastNotNull"]}},
            "fieldConfig": {
                "defaults": {
                    "thresholds": {"mode": "absolute", "steps": [
                        {"color": "red", "value": None},
                        {"color": "yellow", "value": 4},
                        {"color": "green", "value": 6},
                    ]},
                    "mappings": [],
                }
            },
            "targets": [{"datasource": PROM,
                         "expr": 'count(up{job="circleguard-services",namespace="stage"})',
                         "legendFormat": "pods"}],
        },
        {
            "id": 3, "type": "stat", "title": "Request Rate (rps)",
            "gridPos": {"x": 8, "y": 0, "w": 4, "h": 4},
            "options": {"colorMode": "background", "graphMode": "area",
                        "reduceOptions": {"calcs": ["lastNotNull"]}},
            "fieldConfig": {
                "defaults": {
                    "unit": "reqps", "decimals": 2,
                    "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": None}]},
                    "mappings": [],
                }
            },
            "targets": [{"datasource": PROM,
                         "expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage"}[2m]))',
                         "legendFormat": "rps"}],
        },
        {
            "id": 4, "type": "stat", "title": "Latencia p95 (ms)",
            "gridPos": {"x": 12, "y": 0, "w": 4, "h": 4},
            "options": {"colorMode": "background", "graphMode": "none",
                        "reduceOptions": {"calcs": ["lastNotNull"]}},
            "fieldConfig": {
                "defaults": {
                    "unit": "ms", "decimals": 0,
                    "thresholds": {"mode": "absolute", "steps": [
                        {"color": "green", "value": None},
                        {"color": "yellow", "value": 500},
                        {"color": "red", "value": 2000},
                    ]},
                    "mappings": [],
                }
            },
            "targets": [{"datasource": PROM,
                         "expr": 'histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{job="circleguard-services",namespace="stage"}[2m])) by (le)) * 1000',
                         "legendFormat": "p95"}],
        },
        {
            "id": 5, "type": "stat", "title": "Error Rate (rps)",
            "gridPos": {"x": 16, "y": 0, "w": 4, "h": 4},
            "options": {"colorMode": "background", "graphMode": "area",
                        "reduceOptions": {"calcs": ["lastNotNull"]}},
            "fieldConfig": {
                "defaults": {
                    "unit": "reqps", "decimals": 2,
                    "thresholds": {"mode": "absolute", "steps": [
                        {"color": "green", "value": None},
                        {"color": "yellow", "value": 0.05},
                        {"color": "red", "value": 1},
                    ]},
                    "mappings": [],
                }
            },
            "targets": [{"datasource": PROM,
                         "expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage",status=~"4..|5.."}[2m]))',
                         "legendFormat": "errors"}],
        },
        {
            "id": 6, "type": "stat", "title": "JVM Heap Total (MB)",
            "gridPos": {"x": 20, "y": 0, "w": 4, "h": 4},
            "options": {"colorMode": "background", "graphMode": "none",
                        "reduceOptions": {"calcs": ["lastNotNull"]}},
            "fieldConfig": {
                "defaults": {
                    "unit": "decmbytes", "decimals": 0,
                    "thresholds": {"mode": "absolute", "steps": [
                        {"color": "green", "value": None},
                        {"color": "yellow", "value": 600},
                        {"color": "red", "value": 1200},
                    ]},
                    "mappings": [],
                }
            },
            "targets": [{"datasource": PROM,
                         "expr": 'sum(jvm_memory_used_bytes{area="heap",job="circleguard-services",namespace="stage"}) / 1024 / 1024',
                         "legendFormat": "heap MB"}],
        },

        # ── Row 2: Estado por servicio + HTTP rate ────────────────────────────
        {
            "id": 7, "type": "table", "title": "Estado de cada Servicio",
            "gridPos": {"x": 0, "y": 4, "w": 12, "h": 8},
            "options": {"showHeader": True, "sortBy": [{"displayName": "service"}]},
            "fieldConfig": {
                "defaults": {"custom": {"align": "left", "displayMode": "auto"}},
                "overrides": [
                    {
                        "matcher": {"id": "byName", "options": "Value"},
                        "properties": [
                            {
                                "id": "mappings",
                                "value": [{"type": "value", "options": {
                                    "0": {"color": "red", "text": "DOWN", "index": 0},
                                    "1": {"color": "green", "text": "UP", "index": 1},
                                }}],
                            },
                            {"id": "custom.displayMode", "value": "color-background"},
                        ],
                    }
                ],
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'up{job="circleguard-services",namespace="stage"}',
                "legendFormat": "{{service}}",
                "instant": True,
                "format": "table",
            }],
        },
        {
            "id": 8, "type": "timeseries", "title": "HTTP Request Rate por Servicio (rps)",
            "gridPos": {"x": 12, "y": 4, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "reqps",
                    "custom": {"lineWidth": 2, "fillOpacity": 10},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage"}[2m])) by (service)',
                "legendFormat": "{{service}}",
            }],
        },

        # ── Row 3: Latencia + JVM Heap ────────────────────────────────────────
        {
            "id": 9, "type": "timeseries", "title": "HTTP p95 Latencia por Servicio (ms)",
            "gridPos": {"x": 0, "y": 12, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "ms",
                    "custom": {"lineWidth": 2, "fillOpacity": 5},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{job="circleguard-services",namespace="stage"}[2m])) by (le, service)) * 1000',
                "legendFormat": "{{service}}",
            }],
        },
        {
            "id": 10, "type": "timeseries", "title": "JVM Heap Usado por Pod (MB)",
            "gridPos": {"x": 12, "y": 12, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "decmbytes",
                    "custom": {"lineWidth": 2, "fillOpacity": 10},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'jvm_memory_used_bytes{area="heap",job="circleguard-services",namespace="stage"} / 1024 / 1024',
                "legendFormat": "{{pod}}",
            }],
        },

        # ── Row 4: Status code breakdown + GC ────────────────────────────────
        {
            "id": 11, "type": "timeseries", "title": "HTTP Respuestas por Status Code",
            "gridPos": {"x": 0, "y": 20, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "reqps",
                    "custom": {"lineWidth": 2, "fillOpacity": 10},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage"}[2m])) by (status)',
                "legendFormat": "HTTP {{status}}",
            }],
        },
        {
            "id": 12, "type": "timeseries", "title": "JVM GC — Tiempo de pausa (ms/s)",
            "gridPos": {"x": 12, "y": 20, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "ms",
                    "custom": {"lineWidth": 2, "fillOpacity": 5},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'sum(rate(jvm_gc_pause_seconds_sum{job="circleguard-services",namespace="stage"}[2m])) by (pod) * 1000',
                "legendFormat": "{{pod}}",
            }],
        },

        # ── Row 5: Threads + non-heap ─────────────────────────────────────────
        {
            "id": 13, "type": "timeseries", "title": "JVM Threads Activos",
            "gridPos": {"x": 0, "y": 28, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "short",
                    "custom": {"lineWidth": 2, "fillOpacity": 5},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'jvm_threads_live_threads{job="circleguard-services",namespace="stage"}',
                "legendFormat": "{{pod}}",
            }],
        },
        {
            "id": 14, "type": "timeseries", "title": "JVM Non-Heap Memory (MB)",
            "gridPos": {"x": 12, "y": 28, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "decmbytes",
                    "custom": {"lineWidth": 2, "fillOpacity": 5},
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'jvm_memory_used_bytes{area="nonheap",job="circleguard-services",namespace="stage"} / 1024 / 1024',
                "legendFormat": "{{pod}}",
            }],
        },

        # ── Row 6: Circuit Breaker + Texto informativo ────────────────────────
        {
            "id": 15, "type": "timeseries", "title": "Circuit Breaker State",
            "gridPos": {"x": 0, "y": 36, "w": 12, "h": 8},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
            "fieldConfig": {
                "defaults": {
                    "unit": "short",
                    "custom": {"lineWidth": 2},
                    "mappings": [
                        {"type": "value", "options": {
                            "0": {"color": "green", "text": "CLOSED"},
                            "1": {"color": "red", "text": "OPEN"},
                            "2": {"color": "yellow", "text": "HALF_OPEN"},
                        }},
                    ],
                }
            },
            "targets": [{
                "datasource": PROM,
                "expr": 'resilience4j_circuitbreaker_state{job="circleguard-services",namespace="stage"}',
                "legendFormat": "{{name}} — {{pod}}",
            }],
        },
        {
            "id": 16, "type": "text", "title": "URLs de Demo",
            "gridPos": {"x": 12, "y": 36, "w": 12, "h": 8},
            "options": {
                "mode": "markdown",
                "content": (
                    "## CircleGuard — Endpoints de Demo\n\n"
                    "| Servicio | Endpoint |\n"
                    "|----------|----------|\n"
                    "| **Auth** | `:8080/api/v1/auth/login` (POST)  ·  `/api/v1/auth/qr/generate` |\n"
                    "| **Identity** | `:8080/actuator/health` |\n"
                    "| **Promotion** | `:8081/api/v1/buildings` |\n"
                    "| **Gateway** | `:8080/actuator/health` |\n"
                    "| **Dashboard** | `:8080/api/v1/analytics/health-board` |\n"
                    "| **File** | `:8080/actuator/health` |\n\n"
                    "**IPs** → ver stage `START - URLs públicas` en Jenkins\n\n"
                    "> *Auth e Identity requieren cambio Java para exponer `/actuator/prometheus` sin auth.*"
                ),
            },
        },

    ],
}

result = api("/api/dashboards/db", {"dashboard": dashboard, "overwrite": True, "folderId": 0})
print("Status:", result.get("status"))
print("URL:", result.get("url"))
print("Version:", result.get("version"))
