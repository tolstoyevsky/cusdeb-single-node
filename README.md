# Installation #

Sing up or sing in bitbucket.

Generate [ssh key](https://confluence.atlassian.com/bitbucket/set-up-an-ssh-key-728138079.html#SetupanSSHkey-ssh2SetupSSHonmacOS/Linux).

Install packages.
```bash
sudo apt install git docker docker-compose curl pkg-config pandoc supervisor python3-pip postgresql postgresql-server-dev-all qemu-user-static whois -y
pip3 install virtualenv
 ```

Clone project.
```bash
git  clone git@github.com:tolstoyevsky/cusdeb-single-node.git
```

Build project in directory ../cusdeb.
 ```bash
sudo ./single-node.sh build ../cusdeb
```
