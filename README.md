# Installation


Install packages.
```bash
sudo apt install git docker docker-compose curl pkg-config pandoc supervisor python3-pip postgresql postgresql-server-dev-all qemu-user-static whois -y
 ```

Clone project.
```bash
git clone git@github.com:tolstoyevsky/cusdeb-single-node.git
```

Build project in directory ../cusdeb.
 ```bash
sudo ./single-node.sh build ../cusdeb
```
Project depends on some code which is not yet published in GitHub

## Troubleshooting

If you executed the `start` command and encountered the following error

```
docker: Error response from daemon: error while creating mount source path '/srv/mongodb': mkdir /srv/mongodb: read-only file system.
```

try to change the default value of the `VOLUME_PREFIX` environment variable.
