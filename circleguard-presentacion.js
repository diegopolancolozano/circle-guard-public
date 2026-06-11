const pptxgen = require("pptxgenjs");
let pres = new pptxgen();
pres.layout = "LAYOUT_16x9";
pres.title = "CircleGuard - Presentación Final";

// ── Paleta ───────────────────────────────────────────────────────────────────
const NAVY    = "0D1B2A";
const NAVY2   = "0A2540";
const TEAL    = "0EA5E9";
const GREEN   = "10B981";
const WHITE   = "FFFFFF";
const DARK    = "1E293B";
const GRAY    = "64748B";
const LGRAY   = "E2E8F0";
const LBLUE   = "93C5FD";
const LBKG    = "F8FAFC";
const AMBER   = "F59E0B";
const RED     = "EF4444";

const mk = () => ({ type: "outer", blur: 8, offset: 2, angle: 135, color: "000000", opacity: 0.09 });

// ── Helpers ───────────────────────────────────────────────────────────────────
function sectionHeader(slide, title) {
  slide.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.72, fill: { color: NAVY }, line: { color: NAVY } });
  slide.addText(title, { x: 0.4, y: 0, w: 9.2, h: 0.72, fontSize: 20, fontFace: "Calibri", bold: true, color: WHITE, valign: "middle", margin: 0 });
  slide.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0.72, w: 10, h: 0.04, fill: { color: TEAL }, line: { color: TEAL } });
}

function card(slide, x, y, w, h, opts = {}) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: opts.bg || WHITE },
    line: { color: opts.border || LGRAY, width: 1 },
    shadow: mk()
  });
}

function tag(slide, x, y, label, color) {
  slide.addShape(pres.shapes.RECTANGLE, { x, y, w: 1.55, h: 0.35, fill: { color }, line: { color }, shadow: mk() });
  slide.addText(label, { x, y, w: 1.55, h: 0.35, fontSize: 10, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 1 — PORTADA
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: NAVY };

  // Panel derecho oscuro
  s.addShape(pres.shapes.RECTANGLE, { x: 7.2, y: 0, w: 2.8, h: 5.625, fill: { color: NAVY2 }, line: { color: NAVY2 } });

  // Barra teal izquierda
  s.addShape(pres.shapes.RECTANGLE, { x: 0.5, y: 1.9, w: 0.08, h: 2.0, fill: { color: TEAL }, line: { color: TEAL } });

  // Título principal
  s.addText("CircleGuard", {
    x: 0.72, y: 1.85, w: 6.2, h: 1.0,
    fontSize: 52, fontFace: "Calibri", bold: true, color: WHITE, margin: 0
  });

  // Subtítulo
  s.addText("Sistema de Trazabilidad de Contactos Universitario", {
    x: 0.72, y: 2.9, w: 6.2, h: 0.65,
    fontSize: 17, fontFace: "Calibri", color: LBLUE, margin: 0
  });

  // Info curso
  s.addText("Ingeniería de Software V  ·  2026", {
    x: 0.72, y: 3.65, w: 5, h: 0.4,
    fontSize: 12, fontFace: "Calibri", color: GRAY, margin: 0
  });

  // Autor
  s.addText("Diego Polanco Lozano", {
    x: 0.72, y: 4.15, w: 5, h: 0.38,
    fontSize: 13, fontFace: "Calibri", bold: true, color: LBLUE, margin: 0
  });

  // Tags tecnología
  const techTags = [
    { label: "GCP",           color: "1A73E8" },
    { label: "DigitalOcean",  color: "0069FF" },
    { label: "Kubernetes",    color: "326CE5" },
    { label: "Jenkins CI/CD", color: "D33832" },
    { label: "Terraform",     color: "7B42BC" },
  ];
  techTags.forEach((t, i) => {
    s.addShape(pres.shapes.RECTANGLE, { x: 7.35, y: 0.45 + i * 0.92, w: 2.4, h: 0.58, fill: { color: t.color }, line: { color: t.color }, shadow: mk() });
    s.addText(t.label, { x: 7.35, y: 0.45 + i * 0.92, w: 2.4, h: 0.58, fontSize: 13, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 2 — AGENDA
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "Agenda");

  const items = [
    { num: "01", title: "Arquitectura e Infraestructura",       sub: "Multi-cloud, IaC, K8s",                  color: TEAL },
    { num: "02", title: "Demostración de CI/CD",                sub: "Jenkins pipeline, etapas, artefactos",   color: "6366F1" },
    { num: "03", title: "Aplicación en Funcionamiento",         sub: "Microservicios, health checks, HPA",     color: GREEN },
    { num: "04", title: "Dashboards de Monitoreo",              sub: "Grafana, Kibana, Jaeger, Prometheus",    color: AMBER },
    { num: "05", title: "Resultados de Pruebas de Rendimiento", sub: "Carga, caos, autoscaling",               color: RED },
    { num: "06", title: "Lecciones Aprendidas",                 sub: "Recomendaciones y próximos pasos",       color: "8B5CF6" },
  ];

  items.forEach((it, i) => {
    const col = i < 3 ? 0 : 1;
    const row = i % 3;
    const x = col === 0 ? 0.4 : 5.25;
    const y = 1.0 + row * 1.45;

    card(s, x, y, 4.6, 1.2, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x, y, w: 0.07, h: 1.2, fill: { color: it.color }, line: { color: it.color } });
    s.addText(it.num, { x: x + 0.18, y: y + 0.1, w: 0.55, h: 0.45, fontSize: 22, fontFace: "Calibri", bold: true, color: it.color, margin: 0 });
    s.addText(it.title, { x: x + 0.18, y: y + 0.52, w: 4.2, h: 0.38, fontSize: 13, fontFace: "Calibri", bold: true, color: DARK, margin: 0 });
    s.addText(it.sub, { x: x + 0.18, y: y + 0.87, w: 4.2, h: 0.28, fontSize: 10, fontFace: "Calibri", color: GRAY, margin: 0 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 3 — ARQUITECTURA GENERAL
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "01  Arquitectura General — Multi-cloud");

  // --- Cloud GCP (izquierda) ---
  card(s, 0.3, 0.9, 4.2, 4.3, { bg: "EFF6FF", border: "1A73E8" });
  s.addShape(pres.shapes.RECTANGLE, { x: 0.3, y: 0.9, w: 4.2, h: 0.55, fill: { color: "1A73E8" }, line: { color: "1A73E8" } });
  s.addText("☁  Google Cloud Platform (GKE)", { x: 0.3, y: 0.9, w: 4.2, h: 0.55, fontSize: 12, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });

  s.addText("Cluster: circleguard-stage\nRegión: us-central1\nNodos: 3 × e2-standard-2", {
    x: 0.5, y: 1.55, w: 3.8, h: 0.75, fontSize: 10, fontFace: "Calibri", color: DARK, margin: 0
  });

  const gcpSvcs = ["circleguard-gateway-service", "circleguard-auth-service", "circleguard-identity-service", "circleguard-dashboard-service", "circleguard-file-service", "circleguard-promotion-service"];
  gcpSvcs.forEach((svc, i) => {
    s.addShape(pres.shapes.RECTANGLE, { x: 0.5, y: 2.42 + i * 0.38, w: 3.8, h: 0.32, fill: { color: "DBEAFE" }, line: { color: "93C5FD", width: 1 } });
    s.addText(svc, { x: 0.5, y: 2.42 + i * 0.38, w: 3.8, h: 0.32, fontSize: 9.5, fontFace: "Calibri", color: "1E40AF", margin: 4 });
  });

  // --- Flecha central ---
  s.addShape(pres.shapes.LINE, { x: 4.55, y: 3.1, w: 0.85, h: 0, line: { color: TEAL, width: 2.5, dashType: "dash" } });
  s.addText("Terraform\nIaC", { x: 4.58, y: 2.7, w: 0.8, h: 0.55, fontSize: 8, fontFace: "Calibri", bold: true, color: TEAL, align: "center", margin: 0 });

  // --- Cloud DigitalOcean (derecha) ---
  card(s, 5.45, 0.9, 4.2, 4.3, { bg: "EFF6FF", border: "0069FF" });
  s.addShape(pres.shapes.RECTANGLE, { x: 5.45, y: 0.9, w: 4.2, h: 0.55, fill: { color: "0069FF" }, line: { color: "0069FF" } });
  s.addText("☁  DigitalOcean (DOKS + Droplet)", { x: 5.45, y: 0.9, w: 4.2, h: 0.55, fontSize: 12, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });

  s.addText("Cluster: circleguard-cluster\nRegión: nyc1\nJenkins: 104.248.109.57", {
    x: 5.65, y: 1.55, w: 3.8, h: 0.75, fontSize: 10, fontFace: "Calibri", color: DARK, margin: 0
  });

  const doSvcs = ["Jenkins CI/CD (Droplet)", "DOKS — stage namespace", "postgres / redis / kafka", "neo4j / openldap / zookeeper", "monitoring (Prometheus/Grafana)", "Fluent Bit → Kibana (ELK)"];
  doSvcs.forEach((svc, i) => {
    const bg = i === 0 ? "FEE2E2" : i === 4 || i === 5 ? "D1FAE5" : "DBEAFE";
    const bc = i === 0 ? "FCA5A5" : i === 4 || i === 5 ? "6EE7B7" : "93C5FD";
    const tc = i === 0 ? "991B1B" : i === 4 || i === 5 ? "065F46" : "1E40AF";
    s.addShape(pres.shapes.RECTANGLE, { x: 5.65, y: 2.42 + i * 0.38, w: 3.8, h: 0.32, fill: { color: bg }, line: { color: bc, width: 1 } });
    s.addText(svc, { x: 5.65, y: 2.42 + i * 0.38, w: 3.8, h: 0.32, fontSize: 9.5, fontFace: "Calibri", color: tc, margin: 4 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 4 — INFRAESTRUCTURA COMO CÓDIGO
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "01  Infraestructura como Código — Terraform + Kubernetes");

  // Col izquierda: Terraform
  card(s, 0.35, 0.95, 4.4, 4.3, { bg: WHITE });
  s.addShape(pres.shapes.RECTANGLE, { x: 0.35, y: 0.95, w: 4.4, h: 0.48, fill: { color: "7B42BC" }, line: { color: "7B42BC" } });
  s.addText("Terraform IaC", { x: 0.35, y: 0.95, w: 4.4, h: 0.48, fontSize: 14, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });

  const tfItems = [
    ["GCP", "GKE cluster (us-central1)\nVPC + subnets + NAT\nGCS bucket estado remoto\nService Account CI/CD"],
    ["DigitalOcean", "DOKS cluster (nyc1)\nDroplet Jenkins\nSpaces (S3-compat.) backend\nDNS / Firewall"],
  ];
  tfItems.forEach((it, i) => {
    const y = 1.55 + i * 1.8;
    s.addShape(pres.shapes.RECTANGLE, { x: 0.5, y, w: 4.1, h: 0.32, fill: { color: "EDE9FE" }, line: { color: "7B42BC", width: 1 } });
    s.addText(it[0], { x: 0.5, y, w: 4.1, h: 0.32, fontSize: 11, fontFace: "Calibri", bold: true, color: "5B21B6", align: "center", valign: "middle", margin: 0 });
    s.addText(it[1], { x: 0.5, y: y + 0.38, w: 4.1, h: 1.2, fontSize: 10.5, fontFace: "Calibri", color: DARK, margin: 6 });
  });

  // Col derecha: K8s
  card(s, 5.25, 0.95, 4.4, 4.3, { bg: WHITE });
  s.addShape(pres.shapes.RECTANGLE, { x: 5.25, y: 0.95, w: 4.4, h: 0.48, fill: { color: "326CE5" }, line: { color: "326CE5" } });
  s.addText("Kubernetes — K8s/Kustomize", { x: 5.25, y: 0.95, w: 4.4, h: 0.48, fontSize: 14, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });

  const k8sItems = [
    ["Namespaces", "dev / stage / prod / monitoring"],
    ["Workloads",  "Deployments + HPA + PDB"],
    ["Red",        "NetworkPolicies + Istio mTLS STRICT"],
    ["Seguridad",  "RBAC + Secrets + ServiceAccounts"],
    ["TLS",        "cert-manager + Let's Encrypt (nip.io)"],
    ["Observ.",    "Prometheus scrape + Fluent Bit DaemonSet"],
  ];
  k8sItems.forEach((it, i) => {
    const y = 1.55 + i * 0.62;
    s.addShape(pres.shapes.RECTANGLE, { x: 5.4, y, w: 1.25, h: 0.36, fill: { color: "DBEAFE" }, line: { color: "93C5FD", width: 1 } });
    s.addText(it[0], { x: 5.4, y, w: 1.25, h: 0.36, fontSize: 10, fontFace: "Calibri", bold: true, color: "1E40AF", align: "center", valign: "middle", margin: 0 });
    s.addText(it[1], { x: 6.75, y: y + 0.04, w: 2.75, h: 0.32, fontSize: 10, fontFace: "Calibri", color: DARK, margin: 0 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 5 — PIPELINE CI/CD
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "02  Pipeline CI/CD — Jenkins Multibranch");

  const stages = [
    { name: "Checkout",         color: "6366F1", sub: "git clone" },
    { name: "Build & Test",     color: TEAL,     sub: "Maven + JUnit" },
    { name: "SonarQube",        color: "F59E0B", sub: "Code Quality" },
    { name: "Security Scan",    color: RED,      sub: "Trivy + ZAP" },
    { name: "Docker Push",      color: "0EA5E9", sub: "DockerHub" },
    { name: "Deploy K8s",       color: GREEN,    sub: "kubectl apply" },
    { name: "Smoke Tests",      color: "8B5CF6", sub: "curl /health" },
    { name: "Notify",           color: "64748B", sub: "Webhook" },
  ];

  const bw = 1.09;
  const gap = 0.055;
  stages.forEach((st, i) => {
    const x = 0.22 + i * (bw + gap);

    // Box
    s.addShape(pres.shapes.RECTANGLE, { x, y: 1.5, w: bw, h: 1.1, fill: { color: st.color }, line: { color: st.color }, shadow: mk() });
    s.addText(st.name, { x, y: 1.54, w: bw, h: 0.65, fontSize: 11, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
    s.addShape(pres.shapes.RECTANGLE, { x, y: 2.2, w: bw, h: 0.4, fill: { color: WHITE, transparency: 25 }, line: { color: WHITE, transparency: 60, width: 0.5 } });
    s.addText(st.sub, { x, y: 2.2, w: bw, h: 0.4, fontSize: 9, fontFace: "Calibri", color: WHITE, align: "center", valign: "middle", margin: 0 });

    // Flecha (no en el último)
    if (i < stages.length - 1) {
      const ax = x + bw;
      s.addShape(pres.shapes.LINE, { x: ax, y: 2.05, w: gap, h: 0, line: { color: GRAY, width: 1.5 } });
    }
    // Número
    s.addText(String(i + 1), { x, y: 2.72, w: bw, h: 0.3, fontSize: 10, fontFace: "Calibri", color: GRAY, align: "center", margin: 0 });
  });

  // CLOUD_TARGET params
  s.addShape(pres.shapes.RECTANGLE, { x: 0.22, y: 3.15, w: 9.56, h: 0.88, fill: { color: NAVY }, line: { color: NAVY }, shadow: mk() });
  s.addText([
    { text: "Parámetros clave:  ", options: { bold: false, color: GRAY } },
    { text: "CLOUD_TARGET", options: { bold: true, color: TEAL } },
    { text: " = gcp | digitalocean | multi     ", options: { bold: false, color: WHITE } },
    { text: "PIPELINE_MODE", options: { bold: true, color: TEAL } },
    { text: " = full | fast     ", options: { bold: false, color: WHITE } },
    { text: "DEPLOY_ENV", options: { bold: true, color: TEAL } },
    { text: " = dev | stage | prod", options: { bold: false, color: WHITE } },
  ], { x: 0.22, y: 3.15, w: 9.56, h: 0.88, fontSize: 12, fontFace: "Calibri", valign: "middle", margin: 12 });

  // Evidencia badges
  const badges = [
    { label: "Trivy: 0 CRITICAL",  color: GREEN },
    { label: "ZAP: PASS 66 / FAIL 0", color: GREEN },
    { label: "SonarQube: Security A", color: GREEN },
  ];
  badges.forEach((b, i) => {
    s.addShape(pres.shapes.RECTANGLE, { x: 0.22 + i * 3.2, y: 4.2, w: 3.0, h: 0.38, fill: { color: b.color }, line: { color: b.color }, shadow: mk() });
    s.addText(b.label, { x: 0.22 + i * 3.2, y: 4.2, w: 3.0, h: 0.38, fontSize: 11, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 6 — APLICACIÓN FUNCIONANDO
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "03  Aplicación en Funcionamiento — 8 Pods Running");

  // Stats en la parte superior
  const stats = [
    { val: "8/8",    lbl: "Pods Running",      color: GREEN  },
    { val: "3",      lbl: "Clouds / Namespaces", color: TEAL  },
    { val: "HPA",    lbl: "Autoscaling activo", color: "6366F1" },
    { val: "mTLS",   lbl: "Istio STRICT",       color: AMBER },
  ];
  stats.forEach((st, i) => {
    card(s, 0.3 + i * 2.37, 0.9, 2.15, 1.05, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x: 0.3 + i * 2.37, y: 0.9, w: 2.15, h: 0.07, fill: { color: st.color }, line: { color: st.color } });
    s.addText(st.val, { x: 0.3 + i * 2.37, y: 0.95, w: 2.15, h: 0.55, fontSize: 28, fontFace: "Calibri", bold: true, color: st.color, align: "center", margin: 0 });
    s.addText(st.lbl, { x: 0.3 + i * 2.37, y: 1.5, w: 2.15, h: 0.35, fontSize: 10, fontFace: "Calibri", color: GRAY, align: "center", margin: 0 });
  });

  // Lista servicios — 2 columnas
  const svcs = [
    { name: "circleguard-gateway-service",    type: "API Gateway",    color: TEAL    },
    { name: "circleguard-auth-service",       type: "Autenticación",  color: "6366F1"},
    { name: "circleguard-identity-service",   type: "Identidades",    color: "8B5CF6"},
    { name: "circleguard-dashboard-service",  type: "Dashboard",      color: GREEN   },
    { name: "circleguard-file-service",       type: "Archivos QR",    color: AMBER   },
    { name: "circleguard-promotion-service",  type: "Notificaciones", color: RED     },
    { name: "postgres + redis",               type: "Base de datos",  color: "64748B"},
    { name: "kafka + neo4j + openldap",       type: "Infra / Graph",  color: "64748B"},
  ];
  svcs.forEach((sv, i) => {
    const col = i < 4 ? 0 : 1;
    const row = i % 4;
    const x = col === 0 ? 0.3 : 5.15;
    const y = 2.1 + row * 0.8;
    card(s, x, y, 4.6, 0.65, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x, y, w: 0.07, h: 0.65, fill: { color: sv.color }, line: { color: sv.color } });
    s.addText(sv.name, { x: x + 0.18, y: y + 0.06, w: 4.25, h: 0.32, fontSize: 11, fontFace: "Calibri", bold: true, color: DARK, margin: 0 });
    s.addShape(pres.shapes.RECTANGLE, { x: x + 0.18, y: y + 0.37, w: 1.3, h: 0.22, fill: { color: sv.color }, line: { color: sv.color } });
    s.addText(sv.type, { x: x + 0.18, y: y + 0.37, w: 1.3, h: 0.22, fontSize: 8.5, fontFace: "Calibri", color: WHITE, align: "center", valign: "middle", margin: 0 });
    s.addText("1/1 Running", { x: x + 3.1, y: y + 0.38, w: 1.3, h: 0.22, fontSize: 9, fontFace: "Calibri", bold: true, color: GREEN, align: "right", margin: 0 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 7 — OBSERVABILIDAD Y MONITOREO
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "04  Dashboards de Observabilidad");

  const tools = [
    { name: "Prometheus",  desc: "Métricas K8s\nkube-state-metrics\nHPA scraping",           color: "E55126" },
    { name: "Grafana",     desc: "Dashboards FinOps\nAlertas Alertmanager\nNode/Pod metrics", color: "F46800" },
    { name: "Kibana + ELK",desc: "Logs de pods\nFluent Bit DaemonSet\nÍndice circleguard-logs",color: "00BFB3" },
    { name: "Jaeger",      desc: "Trazas distribuidas\nLatencia por microservicio\nSpan trace", color: "60B0E8" },
    { name: "Loki",        desc: "Log aggregation\nPromtail shipper\nGrafana integration",    color: "F5A623" },
    { name: "kube-state",  desc: "Cost metrics\nResource requests\nFinOps visibility",        color: "326CE5" },
  ];

  // 2 filas × 3 columnas
  tools.forEach((t, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 0.3 + col * 3.17;
    const y = 1.0 + row * 2.1;
    card(s, x, y, 2.95, 1.85, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x, y, w: 2.95, h: 0.5, fill: { color: t.color }, line: { color: t.color } });
    s.addText(t.name, { x, y, w: 2.95, h: 0.5, fontSize: 14, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
    s.addText(t.desc, { x: x + 0.15, y: y + 0.58, w: 2.65, h: 1.15, fontSize: 10.5, fontFace: "Calibri", color: DARK, margin: 0 });
  });

  // Nota acceso
  s.addShape(pres.shapes.RECTANGLE, { x: 0.3, y: 5.1, w: 9.4, h: 0.35, fill: { color: NAVY }, line: { color: NAVY } });
  s.addText("Acceso vía port-forward SSH  ·  Grafana: :3000  ·  Kibana: :5601  ·  Jaeger: :16686  ·  Prometheus: :9090", {
    x: 0.3, y: 5.1, w: 9.4, h: 0.35, fontSize: 9.5, fontFace: "Calibri", color: LBLUE, align: "center", valign: "middle", margin: 0
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 8 — SEGURIDAD
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "04  Seguridad — Escaneo Multi-capa");

  // 3 cards grandes
  const secCards = [
    {
      title: "Trivy",    titleColor: RED,
      sub: "Container Vulnerability Scan",
      stats: [
        { label: "CRITICAL", val: "0", color: GREEN },
        { label: "HIGH",     val: "1", color: AMBER },
      ],
      bullets: ["6 imágenes escaneadas en pipeline", "Reporte JSON + TXT archivado", "Falla build si CRITICAL > 0"],
    },
    {
      title: "OWASP ZAP", titleColor: "D33832",
      sub: "Dynamic Application Security Testing",
      stats: [
        { label: "PASS",     val: "66", color: GREEN },
        { label: "FAIL",     val: "0",  color: GREEN },
      ],
      bullets: ["Baseline scan al gateway service", "In-cluster pod (DNS interno)", "WARN-NEW: 1 (cacheable content)"],
    },
    {
      title: "SonarQube", titleColor: AMBER,
      sub: "Static Code Analysis",
      stats: [
        { label: "Security", val: "A", color: GREEN },
        { label: "Reliabil.", val: "A", color: GREEN },
      ],
      bullets: ["23 issues: 3 security + 20 maint.", "NOSONAR en bcrypt seeds (S2068)", "Duplications: 5.6% (aceptable)"],
    },
  ];

  secCards.forEach((sc, i) => {
    const x = 0.3 + i * 3.17;
    card(s, x, 0.9, 2.95, 4.5, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x, y: 0.9, w: 2.95, h: 0.52, fill: { color: sc.titleColor }, line: { color: sc.titleColor } });
    s.addText(sc.title, { x, y: 0.9, w: 2.95, h: 0.52, fontSize: 16, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
    s.addText(sc.sub, { x: x + 0.12, y: 1.5, w: 2.7, h: 0.35, fontSize: 9.5, fontFace: "Calibri", color: GRAY, align: "center", margin: 0 });

    // Stats mini
    sc.stats.forEach((st, j) => {
      const sx = x + 0.2 + j * 1.35;
      s.addShape(pres.shapes.RECTANGLE, { x: sx, y: 1.92, w: 1.2, h: 0.7, fill: { color: st.color, transparency: 85 }, line: { color: st.color, width: 1 } });
      s.addText(st.val, { x: sx, y: 1.95, w: 1.2, h: 0.38, fontSize: 22, fontFace: "Calibri", bold: true, color: st.color, align: "center", margin: 0 });
      s.addText(st.label, { x: sx, y: 2.32, w: 1.2, h: 0.28, fontSize: 8.5, fontFace: "Calibri", color: GRAY, align: "center", margin: 0 });
    });

    // Bullets
    sc.bullets.forEach((b, j) => {
      s.addShape(pres.shapes.OVAL, { x: x + 0.2, y: 2.86 + j * 0.52, w: 0.13, h: 0.13, fill: { color: sc.titleColor }, line: { color: sc.titleColor } });
      s.addText(b, { x: x + 0.42, y: 2.82 + j * 0.52, w: 2.4, h: 0.3, fontSize: 10, fontFace: "Calibri", color: DARK, margin: 0 });
    });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 9 — PRUEBAS DE RENDIMIENTO
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "05  Pruebas de Rendimiento y Resiliencia");

  // HPA
  card(s, 0.3, 0.95, 2.9, 4.35, { bg: WHITE });
  s.addShape(pres.shapes.RECTANGLE, { x: 0.3, y: 0.95, w: 2.9, h: 0.48, fill: { color: "6366F1" }, line: { color: "6366F1" } });
  s.addText("HPA — Autoscaling", { x: 0.3, y: 0.95, w: 2.9, h: 0.48, fontSize: 13, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
  s.addText("Min: 1 réplica\nMax: 3 réplicas\nTrigger: CPU > 70%\nTarget: 50% CPU avg\n\nServicios con HPA:\n· gateway-service\n· auth-service\n· identity-service\n· dashboard-service", {
    x: 0.45, y: 1.55, w: 2.6, h: 3.55, fontSize: 10.5, fontFace: "Calibri", color: DARK, margin: 0
  });

  // Chaos Engineering
  card(s, 3.4, 0.95, 2.9, 4.35, { bg: WHITE });
  s.addShape(pres.shapes.RECTANGLE, { x: 3.4, y: 0.95, w: 2.9, h: 0.48, fill: { color: RED }, line: { color: RED } });
  s.addText("Chaos Engineering", { x: 3.4, y: 0.95, w: 2.9, h: 0.48, fontSize: 13, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
  s.addText("Herramienta: Chaos Mesh\nNamespace: stage\n\nExperimentos ejecutados:\n· Pod kill (auth-service)\n· Network delay 100ms\n· CPU stress 80%\n\nResultado: Pods se\nrecuperaron en < 30s\ngrace period + readiness", {
    x: 3.55, y: 1.55, w: 2.6, h: 3.55, fontSize: 10.5, fontFace: "Calibri", color: DARK, margin: 0
  });

  // Load Test / SLA
  card(s, 6.5, 0.95, 2.9, 4.35, { bg: WHITE });
  s.addShape(pres.shapes.RECTANGLE, { x: 6.5, y: 0.95, w: 2.9, h: 0.48, fill: { color: GREEN }, line: { color: GREEN } });
  s.addText("Resiliencia & SLA", { x: 6.5, y: 0.95, w: 2.9, h: 0.48, fontSize: 13, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });

  const slaStats = [
    { val: "99.9%", lbl: "Uptime SLA" },
    { val: "< 30s", lbl: "Recovery time" },
    { val: "PDB",   lbl: "minAvailable: 1" },
  ];
  slaStats.forEach((st, i) => {
    s.addShape(pres.shapes.RECTANGLE, { x: 6.65, y: 1.55 + i * 0.9, w: 2.6, h: 0.72, fill: { color: GREEN, transparency: 88 }, line: { color: GREEN, width: 1 } });
    s.addText(st.val, { x: 6.65, y: 1.57 + i * 0.9, w: 2.6, h: 0.38, fontSize: 22, fontFace: "Calibri", bold: true, color: GREEN, align: "center", margin: 0 });
    s.addText(st.lbl, { x: 6.65, y: 1.93 + i * 0.9, w: 2.6, h: 0.26, fontSize: 9, fontFace: "Calibri", color: GRAY, align: "center", margin: 0 });
  });
  s.addText("NetworkPolicies por\nnamespace (allow-list)\nRollingUpdate strategy:\nmaxUnavailable: 0\nmaxSurge: 1", {
    x: 6.65, y: 4.28, w: 2.6, h: 0.9, fontSize: 10, fontFace: "Calibri", color: DARK, margin: 0
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 10 — MULTI-CLOUD & FINOPS
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "Multi-cloud & FinOps — GCP + DigitalOcean");

  // Comparativa
  const rows = [
    ["Componente",        "Google Cloud Platform",          "DigitalOcean"],
    ["Cluster K8s",       "GKE Standard — us-central1",     "DOKS — nyc1"],
    ["Nodos",             "3 × e2-standard-2 (2CPU/8GB)",   "3 × s-2vcpu-4gb"],
    ["CI/CD",             "—",                              "Jenkins Droplet (4GB)"],
    ["Estado Terraform",  "GCS bucket",                     "Spaces (S3 compat.)"],
    ["Escalado",          "HPA + Cluster Autoscaler",       "HPA activo"],
    ["Costo est./mes",    "~$0 (efímero, spin-up/down)",    "~$60 USD fijo"],
  ];

  s.addTable(rows.map((r, ri) => r.map((cell, ci) => ({
    text: cell,
    options: {
      fontSize: ri === 0 ? 11 : 10.5,
      fontFace: "Calibri",
      bold: ri === 0 || ci === 0,
      color: ri === 0 ? WHITE : ci === 0 ? DARK : DARK,
      fill: { color: ri === 0 ? NAVY : ci === 1 ? "EFF6FF" : ci === 2 ? "EFF9FF" : WHITE },
      align: "center",
      valign: "middle",
    }
  }))), {
    x: 0.3, y: 0.95, w: 9.4, h: 3.8,
    rowH: [0.48, 0.52, 0.52, 0.52, 0.52, 0.52, 0.52],
    border: { pt: 1, color: LGRAY },
  });

  // FinOps note
  card(s, 0.3, 5.0, 9.4, 0.45, { bg: "FEF3C7", border: AMBER });
  s.addText("FinOps: kube-state-metrics expone resource requests/limits → Grafana FinOps dashboard → visibilidad de costo por servicio en tiempo real", {
    x: 0.45, y: 5.0, w: 9.1, h: 0.45, fontSize: 10.5, fontFace: "Calibri", color: "92400E", valign: "middle", margin: 0
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 11 — LECCIONES APRENDIDAS
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "06  Lecciones Aprendidas");

  const lessons = [
    { num: "1", title: "GKE SSD Quota",            desc: "Los nodos bootstrap de GKE usan pd-balanced (SSD) por defecto. Solución: node_config con disk_type=pd-standard en el cluster resource + node pool.", color: TEAL },
    { num: "2", title: "Terraform State Locks",     desc: "Timeouts de red dejan locks sin liberar. Es fundamental hacer terraform force-unlock proactivamente antes de reintentar deploys.", color: "6366F1" },
    { num: "3", title: "IAM mínimo necesario",       desc: "Eliminar google_project_iam_member cuando la SA no tiene projectIamAdmin. Otorgar solo los permisos que se usan evita errores 403 y mejora la postura de seguridad.", color: RED },
    { num: "4", title: "Docker Hub PAT vs Password", desc: "Jenkins requiere Personal Access Tokens, no contraseñas. Los tokens tienen scopes limitados y son más seguros que credenciales completas.", color: GREEN },
    { num: "5", title: "Port-forward para evidencias", desc: "Sin Ingress externo, el acceso a Kibana/Grafana/Kiali se hace via SSH tunnel + kubectl port-forward. Documentar el flujo para demostraciones.", color: AMBER },
    { num: "6", title: "SonarQube NOSONAR",          desc: "Las hashes bcrypt en seeds SQL disparan S2068 (falso positivo). Suprimir con -- NOSONAR en la línea exacta, no en todo el archivo.", color: "8B5CF6" },
  ];

  lessons.forEach((l, i) => {
    const col = i < 3 ? 0 : 1;
    const row = i % 3;
    const x = col === 0 ? 0.3 : 5.15;
    const y = 0.95 + row * 1.55;
    card(s, x, y, 4.6, 1.38, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x, y, w: 0.07, h: 1.38, fill: { color: l.color }, line: { color: l.color } });
    s.addShape(pres.shapes.OVAL, { x: x + 0.18, y: y + 0.12, w: 0.38, h: 0.38, fill: { color: l.color }, line: { color: l.color } });
    s.addText(l.num, { x: x + 0.18, y: y + 0.12, w: 0.38, h: 0.38, fontSize: 13, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
    s.addText(l.title, { x: x + 0.65, y: y + 0.1, w: 3.8, h: 0.35, fontSize: 12, fontFace: "Calibri", bold: true, color: DARK, margin: 0 });
    s.addText(l.desc, { x: x + 0.65, y: y + 0.48, w: 3.8, h: 0.78, fontSize: 9.5, fontFace: "Calibri", color: GRAY, margin: 0 });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 12 — RECOMENDACIONES
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: LBKG };
  sectionHeader(s, "06  Recomendaciones y Próximos Pasos");

  const recs = [
    { icon: "→", title: "GitOps con ArgoCD",         desc: "Reemplazar el deploy manual kubectl por ArgoCD para sincronización declarativa del estado del cluster con el repositorio Git.", color: TEAL },
    { icon: "→", title: "Dominio real + TLS prod",   desc: "Configurar un dominio propio en lugar de nip.io y usar letsencrypt-prod para certificados válidos en producción.", color: "6366F1" },
    { icon: "→", title: "Vault para secretos",       desc: "Migrar los Kubernetes Secrets a HashiCorp Vault o External Secrets Operator para gestión centralizada y rotación automática.", color: AMBER },
    { icon: "→", title: "Load Testing automatizado", desc: "Integrar k6 o Gatling en el pipeline para pruebas de carga en cada deploy a stage, con umbrales de SLO como quality gates.", color: GREEN },
    { icon: "→", title: "Multi-region activo",       desc: "Evolucionar de multi-cloud activo-pasivo a activo-activo con Global Load Balancer para disaster recovery real.", color: RED },
  ];

  recs.forEach((r, i) => {
    card(s, 0.3, 0.97 + i * 0.91, 9.4, 0.78, { bg: WHITE });
    s.addShape(pres.shapes.RECTANGLE, { x: 0.3, y: 0.97 + i * 0.91, w: 0.07, h: 0.78, fill: { color: r.color }, line: { color: r.color } });
    s.addText(r.title, { x: 0.52, y: 0.97 + i * 0.91 + 0.05, w: 2.5, h: 0.34, fontSize: 12, fontFace: "Calibri", bold: true, color: DARK, margin: 0 });
    s.addText(r.desc, { x: 3.12, y: 0.97 + i * 0.91 + 0.07, w: 6.4, h: 0.6, fontSize: 10.5, fontFace: "Calibri", color: GRAY, margin: 0 });
    s.addShape(pres.shapes.RECTANGLE, { x: 0.52, y: 0.97 + i * 0.91 + 0.44, w: 2.5, h: 0.02, fill: { color: r.color, transparency: 50 }, line: { color: r.color, transparency: 50 } });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 13 — CIERRE
// ══════════════════════════════════════════════════════════════════════════════
{
  let s = pres.addSlide();
  s.background = { color: NAVY };

  s.addShape(pres.shapes.RECTANGLE, { x: 7.2, y: 0, w: 2.8, h: 5.625, fill: { color: NAVY2 }, line: { color: NAVY2 } });
  s.addShape(pres.shapes.RECTANGLE, { x: 0.5, y: 2.05, w: 0.08, h: 1.5, fill: { color: GREEN }, line: { color: GREEN } });

  s.addText("¡Gracias!", { x: 0.72, y: 1.95, w: 6.2, h: 0.85, fontSize: 50, fontFace: "Calibri", bold: true, color: WHITE, margin: 0 });
  s.addText("CircleGuard — Sistema de Trazabilidad de Contactos", { x: 0.72, y: 2.85, w: 6.2, h: 0.55, fontSize: 16, fontFace: "Calibri", color: LBLUE, margin: 0 });

  const links = [
    { label: "Repo GitHub",       val: "diegopolancolozano/circle-guard-public" },
    { label: "Jenkins",           val: "http://104.248.109.57:8080" },
    { label: "Cluster DO",        val: "kubectl get pods -n stage" },
  ];
  links.forEach((lk, i) => {
    s.addText(lk.label + ":  ", { x: 0.72, y: 3.6 + i * 0.42, w: 1.6, h: 0.35, fontSize: 11, fontFace: "Calibri", bold: true, color: GRAY, margin: 0 });
    s.addText(lk.val, { x: 2.35, y: 3.6 + i * 0.42, w: 4.6, h: 0.35, fontSize: 11, fontFace: "Calibri", color: LBLUE, margin: 0 });
  });

  // Badges resumen
  const finalBadges = [
    { lbl: "Multi-cloud GCP+DO", color: "1A73E8" },
    { lbl: "8 Microservicios",   color: TEAL      },
    { lbl: "CI/CD Automatizado", color: GREEN      },
    { lbl: "Seguridad A",        color: "8B5CF6"  },
  ];
  finalBadges.forEach((b, i) => {
    s.addShape(pres.shapes.RECTANGLE, { x: 7.3, y: 0.48 + i * 1.1, w: 2.35, h: 0.68, fill: { color: b.color, transparency: 25 }, line: { color: b.color, width: 1.5 } });
    s.addText(b.lbl, { x: 7.3, y: 0.48 + i * 1.1, w: 2.35, h: 0.68, fontSize: 11.5, fontFace: "Calibri", bold: true, color: WHITE, align: "center", valign: "middle", margin: 0 });
  });
}

// ── Guardar ───────────────────────────────────────────────────────────────────
pres.writeFile({ fileName: "CircleGuard-Presentacion.pptx" })
  .then(() => console.log("✅  CircleGuard-Presentacion.pptx generado"))
  .catch(e => console.error("❌  Error:", e));
