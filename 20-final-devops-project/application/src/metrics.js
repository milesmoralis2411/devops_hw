// Minimal Prometheus instrumentation, written by hand so the exposition
// format is visible. Labels are kept low-cardinality: routes are templates
// ("/api/trips/:id"), never raw paths.
const BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5];

class Metrics {
  constructor(version) {
    this.version = version;
    this.requests = new Map(); // "method|route|status" -> count
    this.latency = new Map();  // route -> { buckets, sum, count }
    this.tripsCreated = 0;
    this.authFailures = 0;
  }

  observe(method, route, status, seconds) {
    const key = `${method}|${route}|${status}`;
    this.requests.set(key, (this.requests.get(key) || 0) + 1);

    if (!this.latency.has(route)) {
      this.latency.set(route, { buckets: BUCKETS.map(() => 0), sum: 0, count: 0 });
    }
    const h = this.latency.get(route);
    BUCKETS.forEach((le, i) => {
      if (seconds <= le) h.buckets[i] += 1;
    });
    h.sum += seconds;
    h.count += 1;
  }

  render(tripCount) {
    const out = [];
    const mem = process.memoryUsage();
    const cpu = process.cpuUsage();

    out.push('# HELP yatri_build_info Build information.', '# TYPE yatri_build_info gauge');
    out.push(`yatri_build_info{version="${this.version}"} 1`);

    out.push('# HELP yatri_trips_stored Trips currently stored.', '# TYPE yatri_trips_stored gauge');
    out.push(`yatri_trips_stored ${tripCount}`);

    out.push('# HELP yatri_trips_created_total Trips created since start.', '# TYPE yatri_trips_created_total counter');
    out.push(`yatri_trips_created_total ${this.tripsCreated}`);

    out.push('# HELP yatri_auth_failures_total Requests rejected for a missing or wrong API key.', '# TYPE yatri_auth_failures_total counter');
    out.push(`yatri_auth_failures_total ${this.authFailures}`);

    out.push('# HELP http_requests_total HTTP requests by method, route and status.', '# TYPE http_requests_total counter');
    for (const [key, n] of this.requests) {
      const [method, route, status] = key.split('|');
      out.push(`http_requests_total{method="${method}",route="${route}",status="${status}"} ${n}`);
    }

    out.push('# HELP http_request_duration_seconds Request latency.', '# TYPE http_request_duration_seconds histogram');
    for (const [route, h] of this.latency) {
      BUCKETS.forEach((le, i) => out.push(`http_request_duration_seconds_bucket{route="${route}",le="${le}"} ${h.buckets[i]}`));
      out.push(`http_request_duration_seconds_bucket{route="${route}",le="+Inf"} ${h.count}`);
      out.push(`http_request_duration_seconds_sum{route="${route}"} ${h.sum.toFixed(6)}`);
      out.push(`http_request_duration_seconds_count{route="${route}"} ${h.count}`);
    }

    out.push('# HELP process_resident_memory_bytes Resident memory in bytes.', '# TYPE process_resident_memory_bytes gauge');
    out.push(`process_resident_memory_bytes ${mem.rss}`);
    out.push('# HELP process_cpu_seconds_total CPU time in seconds.', '# TYPE process_cpu_seconds_total counter');
    out.push(`process_cpu_seconds_total ${((cpu.user + cpu.system) / 1e6).toFixed(6)}`);

    return out.join('\n') + '\n';
  }
}

module.exports = { Metrics };
