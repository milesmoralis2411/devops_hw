# Docker Hello World — Verified Output

All 6 apps were actually built and run on Docker Desktop (Engine v29.7.2, WSL2
backend). Real output captured verbatim below.

## `docker ps` — all 6 apps running

```
NAMES              STATUS          PORTS
hello-react        Up 18 seconds   0.0.0.0:8082->80/tcp
hello-java         Up 2 minutes    0.0.0.0:8085->8080/tcp
hello-nginx        Up 5 minutes    0.0.0.0:8083->80/tcp
hello-apache       Up 6 minutes    0.0.0.0:8081->80/tcp
hello-python       Up 15 minutes   0.0.0.0:5000->5000/tcp
hello-node         Up 17 minutes   0.0.0.0:3000->3000/tcp
```
*(the multi-stage Go app also runs on 8080 — see `../07-docker-multi-stage/`)*

## HTTP responses (curl) — "Hello World" from each

```
$ curl http://localhost:3000    ->  <h1>Hello World from Node.js!</h1>
$ curl http://localhost:5000    ->  <h1>Hello World from Python (Flask)!</h1>
$ curl http://localhost:8085    ->  <h1>Hello World from Java!</h1>
$ curl http://localhost:8081    ->  Apache page  (<h1>Hello World from Apache HTTP Server!</h1>)
$ curl http://localhost:8083    ->  Nginx page   (<h1>Hello World from Nginx!</h1>)
$ curl http://localhost:8082    ->  React SPA
```

### Note on the React app
React renders in the browser, so the served `index.html` is a shell that loads a
JS bundle. The bundle was confirmed to contain the greeting:

```
JS bundle referenced: /assets/index-CWMrw7EZ.js
CONFIRMED: JS bundle contains 'Hello World from React!' (rendered client-side)
```
Open `http://localhost:8082` in a browser to see **Hello World from React!**.

## Image sizes

```
REPOSITORY     TAG       SIZE
hello-node     latest    193MB
hello-python   latest    208MB
hello-java     latest    454MB
hello-apache   latest    175MB
hello-nginx    latest    102MB
hello-react    latest    102MB   (multi-stage: vite build -> nginx)
```

## Reproduce

```bash
# from each app folder
docker build -t <name> .
docker run -d -p <host>:<container> --name <name> <name>
curl http://localhost:<host>
```

Ports used: node 3000, python 5000, java 8085→8080, apache 8081, nginx 8083,
react 8082.
