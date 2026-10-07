// A deliberately simple persistent store: one JSON file on disk.
// In Kubernetes the directory is a PersistentVolumeClaim, so trips survive
// Pod restarts, rescheduling and rolling updates.
//
// Several replicas (scaled by the HPA) share the same file, so every write
// takes an exclusive lock file and re-reads the data first. Without that,
// two Pods writing at once would silently lose each other's updates.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const LOCK_TIMEOUT_MS = 5000;
const STALE_LOCK_MS = 10000;
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

class TripStore {
  constructor(dataDir, maxTrips = 1000) {
    this.dataDir = dataDir;
    this.file = path.join(dataDir, 'trips.json');
    this.lockFile = `${this.file}.lock`;
    this.maxTrips = maxTrips;
    fs.mkdirSync(dataDir, { recursive: true });
  }

  load() {
    try {
      return JSON.parse(fs.readFileSync(this.file, 'utf8'));
    } catch (err) {
      if (err.code === 'ENOENT') return [];
      throw err;
    }
  }

  // Write to a temp file and rename: readers never see a half-written file.
  save(trips) {
    const tmp = `${this.file}.${process.pid}.${crypto.randomUUID()}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(trips, null, 2));
    fs.renameSync(tmp, this.file);
  }

  // O_EXCL ("wx") creation is atomic, so only one process can hold the lock.
  withLock(fn) {
    const deadline = Date.now() + LOCK_TIMEOUT_MS;
    for (;;) {
      try {
        fs.writeFileSync(this.lockFile, String(process.pid), { flag: 'wx' });
        break;
      } catch (err) {
        if (err.code !== 'EEXIST') throw err;
        try {
          // A holder that crashed never releases its lock; break stale ones.
          if (Date.now() - fs.statSync(this.lockFile).mtimeMs > STALE_LOCK_MS) {
            fs.rmSync(this.lockFile, { force: true });
          }
        } catch { /* lock vanished between the two calls - just retry */ }
        if (Date.now() > deadline) {
          throw Object.assign(new Error('storage busy, try again'), { status: 503 });
        }
        sleep(20);
      }
    }
    try {
      return fn();
    } finally {
      fs.rmSync(this.lockFile, { force: true });
    }
  }

  // Readiness check: can we actually write to the volume?
  writable() {
    try {
      fs.accessSync(this.dataDir, fs.constants.W_OK);
      return true;
    } catch {
      return false;
    }
  }

  list() {
    return this.load();
  }

  get(id) {
    return this.load().find((t) => t.id === id);
  }

  add({ destination, days }) {
    return this.withLock(() => {
      const trips = this.load();
      if (trips.length >= this.maxTrips) {
        throw Object.assign(new Error('trip limit reached'), { status: 409 });
      }
      const trip = {
        id: crypto.randomUUID(),
        destination,
        days,
        createdAt: new Date().toISOString(),
      };
      trips.push(trip);
      this.save(trips);
      return trip;
    });
  }

  remove(id) {
    return this.withLock(() => {
      const trips = this.load();
      const kept = trips.filter((t) => t.id !== id);
      if (kept.length === trips.length) return false;
      this.save(kept);
      return true;
    });
  }
}

function validateTrip(body) {
  const errors = [];
  if (!body || typeof body !== 'object') return ['body must be a JSON object'];
  if (typeof body.destination !== 'string' || body.destination.trim().length === 0) {
    errors.push('destination is required');
  } else if (body.destination.length > 100) {
    errors.push('destination must be at most 100 characters');
  }
  if (!Number.isInteger(body.days) || body.days < 1 || body.days > 60) {
    errors.push('days must be an integer between 1 and 60');
  }
  return errors;
}

module.exports = { TripStore, validateTrip };
