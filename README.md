# cusdeb-single-node 

The project is a set of scripts intended for simplifying deployment of CusDeb for developing purposes.

## Installation

Install packages.
```bash
sudo apt install git docker docker-compose curl pkg-config pandoc supervisor python3-pip virtualenv postgresql postgresql-server-dev-all qemu-user-static whois -y
 ```

Clone project.
```bash
git clone git@github.com:tolstoyevsky/cusdeb-single-node.git
```

Create directory cusdeb.
 ```bash
mkdir cusdeb
```
Build project in directory cusdeb.
 ```bash
cd cusdeb-single-node
sudo ./single-node.sh build ../cusdeb
```

## Usage

Script supports the following parameters:

| Parameter    | Description |
|------------|---------|
| build `<target_directory>` | Setup all CusDeb services with all dependences to the `<target_directory>`. It supposed to be empty.
| compilemessages        | Comlipe `.po` files to `.mo` files (see the corresponding [section](https://docs.djangoproject.com/en/2.2/ref/django-admin/#compilemessages) in the official documentation).
| create-superuser       | Create superuser for Django admin interface (see the corresponding [section](https://docs.djangoproject.com/en/2.2/ref/django-admin/#createsuperuser) in the official documentation).
| dbshell                | Connect to the project's database (see the corresponding [section](https://docs.djangoproject.com/en/2.2/ref/django-admin/#dbshell) in the official documentation).
| loaddata `<fixture>`   | Read the data from the specified fixture and load it into the database (note that `<fixture>` must be a full path to the fixture file) (see the corresponding [section](https://docs.djangoproject.com/en/2.2/ref/django-admin/#loaddata) in the official documentation).
| makemigrations         | Generate migrations based on changes in models (see the corresponding [section](https://docs.djangoproject.com/en/2.2/ref/django-admin/#makemigrations) in the official documentation).
| migrate                | Apply all migrations (see the corresponding [section](https://docs.djangoproject.com/en/2.2/ref/django-admin/#migrate) in the official documentation).
| rebuild  [`<full>`]    | Clean the directory the CusDeb services were installed to (see the `build` command) and re-setup all the services. By default, the chroot environments will be left when cleaning the directory. If you want to re-setup not only the CusDeb services but also chroot environments, pass `full` as the first argument to `rebuild`.
| remove                 | Clean the directory the CusDeb services were installed to (see the `build` command).
| restart                | Restart all services.
| shell                  | Start Python interpreter with established enviroment.
| start                  | Start all services.
| stop                   | Stop all services.


When you start services you can specify the ports for them via the `BM_PORT` and `DOMINION_PORT` environment variables. For example:
```
sudo env BM_PORT=9000 ./single-node.sh start
``` 
Default ports are:

| Service                                                   | Default |
|-----------------------------------------------------------|---------|
| [CusDeb API](https://github.com/tolstoyevsky/cusdeb-api)  | 8001    |
| [Black Magic](https://github.com/tolstoyevsky/blackmagic) | 8002    |
| [Dominion](https://github.com/tolstoyevsky/dominion)      | 8003    |
| [Orion](https://github.com/tolstoyevsky/orion)            | 8004    |

## Authors

See [AUTHORS](https://github.com/tolstoyevsky/cusdeb-single-node/blob/master/AUTHORS.md).
    
## Licensing

cusdeb-single-node is available under the [Apache License, Version 2.0.](https://github.com/tolstoyevsky/cusdeb-single-node/blob/master/LICENSE)

