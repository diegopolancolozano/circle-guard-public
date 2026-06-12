#!/usr/bin/env python3
"""Generate indented dashboard JSON for embedding in grafana.yaml ConfigMap."""
import json

panels = [
    # Row 1: Stats
    {"id": 1, "type": "stat", "title": "Servicios UP",
     "gridPos": {"h": 4, "w": 4, "x": 0, "y": 0},
     "options": {"colorMode": "background", "graphMode": "none",
                 "reduceOptions": {"calcs": ["lastNotNull"]}},
     "fieldConfig": {"defaults": {
         "thresholds": {"mode": "absolute", "steps": [
             {"color": "red", "value": None},
             {"color": "yellow", "value": 3},
             {"color": "green", "value": 6},
         ]},
         "mappings": [],
     }},
     "targets": [{"expr": 'count(up{job="circleguard-services",namespace="stage"} == 1)',
                  "legendFormat": "up"}]},

    {"id": 2, "type": "stat", "title": "Pods Running",
     "gridPos": {"h": 4, "w": 4, "x": 4, "y": 0},
     "options": {"colorMode": "background", "graphMode": "none",
                 "reduceOptions": {"calcs": ["lastNotNull"]}},
     "fieldConfig": {"defaults": {
         "thresholds": {"mode": "absolute", "steps": [
             {"color": "red", "value": None},
             {"color": "yellow", "value": 4},
             {"color": "green", "value": 6},
         ]},
         "mappings": [],
     }},
     "targets": [{"expr": 'count(up{job="circleguard-services",namespace="stage"})',
                  "legendFormat": "pods"}]},

    {"id": 3, "type": "stat", "title": "Request Rate (rps)",
     "gridPos": {"h": 4, "w": 4, "x": 8, "y": 0},
     "options": {"colorMode": "background", "graphMode": "area",
                 "reduceOptions": {"calcs": ["lastNotNull"]}},
     "fieldConfig": {"defaults": {
         "unit": "reqps", "decimals": 2,
         "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": None}]},
         "mappings": [],
     }},
     "targets": [{"expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage"}[2m]))',
                  "legendFormat": "rps"}]},

    {"id": 4, "type": "stat", "title": "Latencia p95 (ms)",
     "gridPos": {"h": 4, "w": 4, "x": 12, "y": 0},
     "options": {"colorMode": "background", "graphMode": "none",
                 "reduceOptions": {"calcs": ["lastNotNull"]}},
     "fieldConfig": {"defaults": {
         "unit": "ms", "decimals": 0,
         "thresholds": {"mode": "absolute", "steps": [
             {"color": "green", "value": None},
             {"color": "yellow", "value": 500},
             {"color": "red", "value": 2000},
         ]},
         "mappings": [],
     }},
     "targets": [{"expr": 'histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{job="circleguard-services",namespace="stage"}[2m])) by (le)) * 1000',
                  "legendFormat": "p95"}]},

    {"id": 5, "type": "stat", "title": "Error Rate (rps)",
     "gridPos": {"h": 4, "w": 4, "x": 16, "y": 0},
     "options": {"colorMode": "background", "graphMode": "area",
                 "reduceOptions": {"calcs": ["lastNotNull"]}},
     "fieldConfig": {"defaults": {
         "unit": "reqps", "decimals": 2,
         "thresholds": {"mode": "absolute", "steps": [
             {"color": "green", "value": None},
             {"color": "yellow", "value": 0.05},
             {"color": "red", "value": 1},
         ]},
         "mappings": [],
     }},
     "targets": [{"expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage",status=~"4..|5.."}[2m]))',
                  "legendFormat": "errors"}]},

    {"id": 6, "type": "stat", "title": "JVM Heap Total (MB)",
     "gridPos": {"h": 4, "w": 4, "x": 20, "y": 0},
     "options": {"colorMode": "background", "graphMode": "none",
                 "reduceOptions": {"calcs": ["lastNotNull"]}},
     "fieldConfig": {"defaults": {
         "unit": "decmbytes", "decimals": 0,
         "thresholds": {"mode": "absolute", "steps": [
             {"color": "green", "value": None},
             {"color": "yellow", "value": 600},
             {"color": "red", "value": 1200},
         ]},
         "mappings": [],
     }},
     "targets": [{"expr": 'sum(jvm_memory_used_bytes{area="heap",job="circleguard-services",namespace="stage"}) / 1024 / 1024',
                  "legendFormat": "heap MB"}]},

    # Row 2: Per-service health table + HTTP rate
    {"id": 7, "type": "table", "title": "Estado de cada Servicio",
     "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
     "options": {"showHeader": True},
     "fieldConfig": {
         "defaults": {"custom": {"align": "left", "displayMode": "auto"}},
         "overrides": [{
             "matcher": {"id": "byName", "options": "Value"},
             "properties": [
                 {"id": "mappings", "value": [{"type": "value", "options": {
                     "0": {"color": "red", "text": "DOWN", "index": 0},
                     "1": {"color": "green", "text": "UP", "index": 1},
                 }}]},
                 {"id": "custom.displayMode", "value": "color-background"},
             ],
         }],
     },
     "targets": [{"expr": 'up{job="circleguard-services",namespace="stage"}',
                  "legendFormat": "{{service}}", "instant": True, "format": "table"}]},

    {"id": 8, "type": "timeseries", "title": "HTTP Request Rate por Servicio (rps)",
     "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "reqps",
                                  "custom": {"lineWidth": 2, "fillOpacity": 10}}},
     "targets": [{"expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage"}[2m])) by (service)',
                  "legendFormat": "{{service}}"}]},

    # Row 3: Latency + JVM Heap
    {"id": 9, "type": "timeseries", "title": "HTTP p95 Latencia por Servicio (ms)",
     "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "ms",
                                  "custom": {"lineWidth": 2, "fillOpacity": 5}}},
     "targets": [{"expr": 'histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{job="circleguard-services",namespace="stage"}[2m])) by (le, service)) * 1000',
                  "legendFormat": "{{service}}"}]},

    {"id": 10, "type": "timeseries", "title": "JVM Heap Usado por Pod (MB)",
     "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "decmbytes",
                                  "custom": {"lineWidth": 2, "fillOpacity": 10}}},
     "targets": [{"expr": 'jvm_memory_used_bytes{area="heap",job="circleguard-services",namespace="stage"} / 1024 / 1024',
                  "legendFormat": "{{pod}}"}]},

    # Row 4: Status breakdown + GC
    {"id": 11, "type": "timeseries", "title": "HTTP Respuestas por Status Code",
     "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "reqps",
                                  "custom": {"lineWidth": 2, "fillOpacity": 10}}},
     "targets": [{"expr": 'sum(rate(http_server_requests_seconds_count{job="circleguard-services",namespace="stage"}[2m])) by (status)',
                  "legendFormat": "HTTP {{status}}"}]},

    {"id": 12, "type": "timeseries", "title": "JVM GC — Tiempo de pausa (ms/s)",
     "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "ms",
                                  "custom": {"lineWidth": 2, "fillOpacity": 5}}},
     "targets": [{"expr": 'sum(rate(jvm_gc_pause_seconds_sum{job="circleguard-services",namespace="stage"}[2m])) by (pod) * 1000',
                  "legendFormat": "{{pod}}"}]},

    # Row 5: Threads + Non-Heap
    {"id": 13, "type": "timeseries", "title": "JVM Threads Activos",
     "gridPos": {"h": 8, "w": 12, "x": 0, "y": 28},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "short",
                                  "custom": {"lineWidth": 2, "fillOpacity": 5}}},
     "targets": [{"expr": 'jvm_threads_live_threads{job="circleguard-services",namespace="stage"}',
                  "legendFormat": "{{pod}}"}]},

    {"id": 14, "type": "timeseries", "title": "JVM Non-Heap Memory (MB)",
     "gridPos": {"h": 8, "w": 12, "x": 12, "y": 28},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "decmbytes",
                                  "custom": {"lineWidth": 2, "fillOpacity": 5}}},
     "targets": [{"expr": 'jvm_memory_used_bytes{area="nonheap",job="circleguard-services",namespace="stage"} / 1024 / 1024',
                  "legendFormat": "{{pod}}"}]},

    # Row 6: Circuit Breaker
    {"id": 15, "type": "timeseries",
     "title": "Circuit Breaker State (0=CLOSED  1=OPEN  2=HALF_OPEN)",
     "gridPos": {"h": 8, "w": 24, "x": 0, "y": 36},
     "options": {"legend": {"displayMode": "list", "placement": "bottom"}},
     "fieldConfig": {"defaults": {"unit": "short", "custom": {"lineWidth": 2}}},
     "targets": [{"expr": 'resilience4j_circuitbreaker_state{job="circleguard-services",namespace="stage"}',
                  "legendFormat": "{{name}} — {{pod}}"}]},
]

dashboard = {
    "title": "CircleGuard Services",
    "uid": "circleguard-overview",
    "schemaVersion": 38,
    "time": {"from": "now-30m", "to": "now"},
    "refresh": "30s",
    "panels": panels,
}

js = json.dumps(dashboard, ensure_ascii=False, indent=2)
# Indent 4 spaces for YAML literal block (inside ConfigMap data key)
indented = "\n".join("    " + line for line in js.splitlines())
print(indented)
