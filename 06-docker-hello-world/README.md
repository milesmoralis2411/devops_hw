# Docker Hello World Applications

Six "Hello World" web applications, each in its own folder with application code
and a `Dockerfile`, per the required structure:

```
06-docker-hello-world/
├── nodejs-app/     # Node.js HTTP server        -> port 3000
├── python-app/     # Python Flask app           -> port 5000
├── java-app/       # Java HttpServer (JDK)       -> port 8080
├── Apache-app/     # Apache httpd serving HTML   -> port 80
├── React-app/      # React (Vite) built + Nginx  -> port 80
└── nginx-app/      # Nginx serving static HTML   -> port 80
```

## Build & run each app

Run these from inside each app's folder. Then open the URL and confirm
**"Hello World"** is shown.

### nodejs-app
```bash
cd nodejs-app
docker build -t hello-node .
docker run -d -p 3000:3000 --name hello-node hello-node
curl http://localhost:3000        # -> Hello World from Node.js!
```
> Verified locally (running `node server.js` directly): `curl` returned
> `<h1>Hello World from Node.js!</h1>`.

### python-app
```bash
cd python-app
docker build -t hello-python .
docker run -d -p 5000:5000 --name hello-python hello-python
curl http://localhost:5000        # -> Hello World from Python (Flask)!
```

### java-app
```bash
cd java-app
docker build -t hello-java .
docker run -d -p 8080:8080 --name hello-java hello-java
curl http://localhost:8080        # -> Hello World from Java!
```

### Apache-app
```bash
cd Apache-app
docker build -t hello-apache .
docker run -d -p 8081:80 --name hello-apache hello-apache
curl http://localhost:8081        # -> Hello World from Apache HTTP Server!
```

### React-app
```bash
cd React-app
docker build -t hello-react .     # multi-stage: npm build -> nginx
docker run -d -p 8082:80 --name hello-react hello-react
# open http://localhost:8082      -> Hello World from React!
```

### nginx-app
```bash
cd nginx-app
docker build -t hello-nginx .
docker run -d -p 8083:80 --name hello-nginx hello-nginx
curl http://localhost:8083        # -> Hello World from Nginx!
```

## Verify all running containers

```bash
docker ps
```

> ✅ Screenshots of all 6 webpages and `docker ps` are in
> [`screenshots/`](screenshots/) and embedded in [`EVIDENCE.md`](EVIDENCE.md).

## Cleanup

```bash
docker rm -f hello-node hello-python hello-java hello-apache hello-react hello-nginx
```

---

### Notes on each Dockerfile
- **nodejs-app** — `node:20-alpine`, runs `server.js` (native `http` module, no deps).
- **python-app** — `python:3.12-slim`, `pip install flask`, runs `app.py`.
- **java-app** — multi-stage: compiles `Main.java` with a JDK image, runs the
  `.class` on a smaller JRE image.
- **Apache-app** — `httpd:2.4`, copies `index.html` into `htdocs`.
- **React-app** — multi-stage: `node:20-alpine` builds the Vite bundle, then the
  static `dist/` is served by `nginx:alpine`.
- **nginx-app** — `nginx:alpine`, copies `index.html` into the web root.
