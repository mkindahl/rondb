# NDB Kubernetes Images

This directory contains entrypoint scripts for the NDB Cluster Docker
images intended for Kubernetes deployment. The images are built from
[Dockerfile.ndb](../Dockerfile.ndb) at the repo root.

## Images

| Target | Description |
|--------|-------------|
| `ndbd` | NDB data node (`ndbmtd` by default, `ndbd` as fallback) |
| `ndb_mgmd` | NDB management server and management client (`ndb_mgm`) |

## Building

```sh
docker build -f Dockerfile.ndb --target ndbd    -t ndbd    .
docker build -f Dockerfile.ndb --target ndb_mgmd -t ndb_mgmd .
```

Both images share a common builder stage. If your Docker daemon supports
parallel builds, both can be built in one invocation:

```sh
docker build -f Dockerfile.ndb --target ndbd     -t ndbd     . &
docker build -f Dockerfile.ndb --target ndb_mgmd -t ndb_mgmd . &
wait
```

### Build arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `BUILD_THREADS` | `1` | Parallel compile jobs passed to cmake (`-j`) |
| `BOOST_VERSION_MAJOR` | `1` | Boost major version |
| `BOOST_VERSION_MINOR` | `77` | Boost minor version |
| `BOOST_VERSION_PATCH` | `0` | Boost patch version |

Example with 8 compile threads:

```sh
docker build -f Dockerfile.ndb --target ndbd -t ndbd \
    --build-arg BUILD_THREADS=8 .
```

## Running locally

Start a management node with a bind-mounted config file:

```sh
docker run --rm \
    -v /path/to/config.ini:/etc/ndb/config.ini \
    -v ndb-mgmd-data:/var/lib/ndb_mgmd \
    -p 1186:1186 \
    ndb_mgmd
```

Start a data node pointing at the management server:

```sh
docker run --rm \
    -e NDB_MGM_HOSTS=<mgmd-host>:1186 \
    -v ndb-data:/var/lib/ndb \
    ndbd
```

Check cluster status from inside the management container:

```sh
docker exec <mgmd-container> ndb_mgm -e "show"
```

## Environment variables

### `ndbd`

| Variable | Default | Description |
|----------|---------|-------------|
| `NDB_MGM_HOSTS` | `localhost:1186` | Comma-separated `host:port` list of management servers. **Required.** |
| `NDB_NODE_ID` | _(pod ordinal)_ | Explicit node ID. If unset, derived from the trailing ordinal in `$HOSTNAME` (StatefulSet pods). |
| `NDB_DAEMON` | `ndbmtd` | Binary to run: `ndbmtd` (multithreaded) or `ndbd` (single-threaded). |

### `ndb_mgmd`

| Variable | Default | Description |
|----------|---------|-------------|
| `NDB_MGMD_DIR` | `/var/lib/ndb_mgmd` | Working directory for mgmd state. Mount a PersistentVolume here. |
| `NDB_CONFIG_FILE` | `/etc/ndb/config.ini` | Path to the cluster config file. Provide via a ConfigMap. |

## Kubernetes deployment

- Deploy `ndb_mgmd` as a `StatefulSet` with a `PersistentVolumeClaim` for
  `NDB_MGMD_DIR` and a `ConfigMap` providing `/etc/ndb/config.ini`.
- Deploy `ndbd` as a `StatefulSet` (one pod per data node) with a
  `PersistentVolumeClaim` for `/var/lib/ndb`.
- NDB Cluster supports at most **2 management nodes**.
- Data nodes receive all configuration from the management server at connect
  time; no config file is needed in the data node pods.

### Deploying with MicroK8s on Ubuntu

[MicroK8s](https://microk8s.io) is a lightweight Kubernetes distribution
available as a snap on Ubuntu.

**1. Install MicroK8s**

```sh
sudo snap install microk8s --classic
sudo usermod -aG microk8s $USER
newgrp microk8s
```

**2. Enable required add-ons**

The `dns` add-on is required for the headless Service DNS names
(`ndb-mgmd-0.ndb-mgmd`, etc.) to resolve between pods. The `storage` add-on
provides a default `StorageClass` for the `PersistentVolumeClaims`.

```sh
microk8s enable dns storage
```

**3. Build the images**

```sh
docker build -f Dockerfile.ndb --target ndbd     -t ndbd     .
docker build -f Dockerfile.ndb --target ndb_mgmd -t ndb_mgmd .
```

**4. Import images into MicroK8s**

MicroK8s uses its own containerd instance and does not share the Docker image
store. Import each image directly:

```sh
docker save ndbd     | microk8s ctr image import -
docker save ndb_mgmd | microk8s ctr image import -
```

The manifests use `imagePullPolicy: IfNotPresent`, so MicroK8s will use these
local images without attempting to pull from a registry.

**5. Deploy**

```sh
microk8s kubectl apply -f docker/k8s.yaml
```

**6. Check cluster status**

```sh
microk8s kubectl get pods
microk8s kubectl exec ndb-mgmd-0 -- ndb_mgm -e "show"
```
