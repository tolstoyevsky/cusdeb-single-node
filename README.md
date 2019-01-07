# cusdeb-single-node 

The project is a set of scripts intended for simplifying deployment of CusDeb for developing purposes.

WARNING: cusdeb-single-node depends on some code which is not yet published in GitHub.

## Installation

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

## Usage

Script supports the following parameters:

| Parameter    | Description |
|------------|---------|
| build `<target_directory>` | Setup all CusDeb services with all dependences to the `<target_directory>`. It supposed to be empty.
| start                  | Start all services.
| stop                   | Stop all services.
| create-superuser       | Create superuser for Django admin interface.
| dbshell                | Connect to the project's database.
| loaddata `<fixture>`   | Read the data from the specified fixture and load it into the database (note that `<fixture>` must be a full path to the fixture file).
| makemigrations         | Generate migrations based on changes in models.
| migrate                | Apply all migrations.
| makemessages           | Create `.po` files from `.html`, `.py` and `.txt` files and place them in dashboard/locale for translation.
| compilemessages        | Comlipe `.po` files to `.mo` files.
| shell                  | Start Python interpreter with established enviroment.
| rebuild  [`<full>`]    | Clean the directory the CusDeb services were installed to (see the `build` command) and re-setup all the services. By default, the chroot environments will be left when cleaning the directory. If you want to re-setup not only the CusDeb services but also chroot environments, pass `full` as the first argument to `rebuild`.
| restart                | Restart all services.


When you start services you can specify the ports for them via the `DASHBOARD_PORT`, `BM_PORT` and `DOMINION_PORT` environment variables. For example: 
```
sudo env DASHBOARD_PORT=3000 ./single-node.sh start
``` 
Default ports are:

| Service                                                   | Default |
|-----------------------------------------------------------|---------|
| Dashboard                                                 | 8001    |
| [Black Magic](https://github.com/tolstoyevsky/blackmagic) | 8002    |
| [Dominion](https://github.com/tolstoyevsky/dominion)      | 8003    |
| [Orion](https://github.com/tolstoyevsky/orion)            | 8004    |

## Troubleshooting

If you executed the `start` command and encountered the following error

```
docker: Error response from daemon: error while creating mount source path '/srv/mongodb': mkdir /srv/mongodb: read-only file system.
```

try to change the default value of the `VOLUME_PREFIX` environment variable.

## Authors

See [AUTHORS](https://github.com/tolstoyevsky/cusdeb-single-node/blob/master/AUTHORS.md).
    
## Licensing

cusdeb-single-node is available under the [Apache License, Version 2.0.](https://github.com/tolstoyevsky/cusdeb-single-node/blob/master/LICENSE)

