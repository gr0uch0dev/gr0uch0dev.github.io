---
layout: post
title: Reduce your attack surface at development stage separating where you write code from where you test it. Docker a good compromise.
date: 2023-02-04
---

<meta property="og:image" content="https://icon-library.com/images/docker-container-icon/docker-container-icon-26.jpg">

## Intro

In the recent years `Docker` and containerization have revolutionized the way we package and ship applications into running environments.

But there is actually one other benefit that `Docker` brings to the table, namely its capability to reduce the attack surface on our main hosts.

With the spike in supply-chain and typo-squatting attacks, containerization can play an important role into reducing the risks of malicious activities from third party components.

Here we focus on the security benefits that `Docker` can already bring at development stages. Risks and security concerns that generally hold for `Docker` are out of scope. It is just important to stress that containers are not virtual machines. Undoubtedly there exists more secure (and real) isolation than containers, nevertheless, they can bring huge benefits in creating more secure environments.

We use the term `host` to refer to the machine where the `Docker` engine is being run.

The article shows, step by step, how to create development environments using `Docker` containers and the benefits they bring into separating the context where we write code from the one where we actually run it.

We use the term `development environment` to refer to the context where we want to install all the dependencies that are required to test our application. The word `development` resembles the idea that we want to create contexts that change during developing activities. Sometimes we refer to this environment as `the running context` since its main objective is to actually run the application we are developing.

The main idea is to write code using editor or IDEs that are installed on our `host` but the code is tested on different environments that are isolated from the `host`.
 
In conclusion, we present how a feature of Visual Studio Code can be used to ease the development process inside containers.

Even if not necessary, familiarity with basic `Docker` concepts is assumed here.

## Environment setup and first run

To follow a naming convention, assuming that we are developing `my_app`, we will create a `Docker` image named `myapp_dev_environment` to spawn containers that are able to run the application `my_app`. 

The objective of `my_app` for now is just a simple `javascript` to create some beautiful visual `ascii art`.

```js
var figlet = require('figlet');

figlet('Hello Dear!!', function(err, data) {
    if (err) {
        console.log('Something went wrong...');
        console.dir(err);
        return;
    }
    console.log(data)
});
```

We save the above code in `app/main.js` into an arbitrary directory of our `host`. The current structure looks like this

```
$ tree app/
app/
└── main.js
```

We try to run `main.js` on our `host`

```
$ node app/main.js 
bash: node: command not found
```

`node` is not installed.

We could just rush and install it via an available package manager

```
sudo apt-get install nodejs -y
```

but what if we mistype `nodejs` and instead write `nodejss`? What if that `nodejss` installed by mistake turns out to be a malicious package that starts doing dirty stuff on our `host` upon installation?

What if `nodejs` (the actual legit package) has critical vulnerabilities in itself or in one of its dependencies?

What if one of the components `nodejs` depends on gets compromised and we get malicious artifacts unintentionally?

Lets assume `nodejs` installed via `apt-get` is `100%` safe, what about `figlet`, the `node` package we want to use to create our nice `ascii art`?

What if we type `figllet` instead of `figlet` while running `npm install` and the former brings malicious code with it?

Reasoning can go on indefinitely.

We just wanted to run some `node` but we ended up increasing our attack surface!

Ok, installing `node` on our `host` seems to be dangerous, but we still need to develop our application.

We start creating a `Dockerfile` into our directory

```Dockerfile
FROM node
```

for now we apparently need just a `node` environment.

Current folder structure is

```
$ tree .
.
├── app
│   └── main.js
└── Dockerfile

```

The aim of this `Docker` image is creating an environment in which we can run our application that we are creating on our `host` (using an editor or IDE of our choice).

We build a Docker image named `myapp_dev_environment`

```
docker build -t myapp_dev_environment .
```

The application is still in development stage. At this time we want to use `Docker` just to have an execution environment to be used for development purposes. This is why in the `Dockerfile` we are not copying the content of the application. 

If you have familiarity with `Docker` you have probably seen instructions like `COPY app/ /app` that where copying contents from the filesystem of the `host` to the one of the container. We usually use this when we have an app that is ready to be run and we embed it directly into the `Docker` image. This is done **to ship** the application, i.e. to provide an application together with its execution environment.

In our scenario we want to use `Docker` to spawn an environment in which we want to develop our application. We do not want to (yet) embed our application code inside the image (we still have to create the code).

To achieve this we use `Docker` volumes to share at runtime the application code with the container.

With the environment built we can try to run the application with the following

```
docker run --rm -v $PWD/app:/app myapp_dev_environment node /app/main.js 
```

`-v $PWD/app:/app ` to bind the directory of the `host` where we are developing the application (`app/`) with the one of the container where we want to place our application (`/app`). This allows us to share the app with the container at runtime.

`--rm` flag added to remove the container upon exiting.

When the container starts it executes `node /app/main.js` inside the container context. 

But we have the following output

```
$ docker run --rm -v $PWD/app:/app myapp_dev_environment node /app/main.js
node:internal/modules/cjs/loader:1042
  throw err;
  ^

Error: Cannot find module 'figlet'
```

The environment that the container spawn from the Docker image `myapp_dev_environment` it has `node` but it is missing the `figlet` package we need in order to create `ascii art`.

An idea would be to write the following `Dockerfile`

```Dockerfile
FROM node
WORKDIR /app
RUN npm install -g figlet
```

We build it

```
docker build -t myapp_dev_environment .
```

We then try to run the application but get the same error as before

```
$ docker run --rm -it -v $PWD/app:/app myapp_dev_environment /app/main.js
node:internal/modules/cjs/loader:1042
  throw err;
  ^

Error: Cannot find module 'figlet'
```

The error is caused by the mounting of `$PWD/app` of the `host` with `/app` of the container. The content of the latter gets replaced by the one of the former upon binding. In our `Dockerfile` we run `npm install figlet` with `/app` as the working directory. This means that `npm` produces its execution artifacts, like `node_modules`, under container `/app`. But when we do the binding `$PWD/app:/app` the content of the container gets overwritten with the one of the `host` in `$PWD/app`. This is why the module `figlet` is still not found, because `node_modules` is no longer there.

We can come with a workaround.

We make the `Dockerfile` create all the `npm` artifacts (node modules and packages info) into a temporary directory `/dev-dependencies` and then use an `entrypoint` script that is executed as soon as the container spawns. Such `entrypoint` will move the contents from `/dev-dependencies` to `/app` inside the container. This works because `entrypoint` is executed just after the volume binding.

We create a new file named `entrypoint.sh`

```
$ tree .
.
├── app
│   └── main.js
├── Dockerfile
└── entrypoint.sh
```

with the following content

```bash
#!/bin/bash

# clean previous artifacts if present in folder shared with the host
rm -rf /app/node_module
rm -f /app/{package,package-lock}.json
###

mv -R /dev-dependencies/* /app/
node $@
```

The last line `node $@` allows us to specify directly the `js` file to execute when using `docker run` instructions as it will be shown below.
 
We replace the content in `Dockerfile` with the following

```Dockerfile
FROM node
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

WORKDIR /dev-dependencies
RUN npm install figlet


WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]
```

We build

```
docker build -t myapp_dev_environment .
```

We run the container knowing that the last instruction of the `entrypoint` is `node $@` so that we can just provide `main.js` as argument (`WORKDIR` is `/app`).

```bash
$ docker run --rm -it -v $PWD/app:/app myapp_dev_environment main.js
  _   _      _ _         ____                  _ _ 
 | | | | ___| | | ___   |  _ \  ___  __ _ _ __| | |
 | |_| |/ _ \ | |/ _ \  | | | |/ _ \/ _` | '__| | |
 |  _  |  __/ | | (_) | | |_| |  __/ (_| | |  |_|_|
 |_| |_|\___|_|_|\___/  |____/ \___|\__,_|_|  (_|_)

```

We are able to execute the application correctly!

But we are actually still developing our app. Now assume that we want to use an other `node` package inside our application, namely `cli`.

We add the following line to `main.js`

```js
var cli = require('cli');
```

We run again the application using the same instruction as before

```bash
$ docker run --rm -it -v $PWD/app:/app myapp_dev_environment main.js
node:internal/modules/cjs/loader:1042
  throw err;
  ^

Error: Cannot find module 'cli'

```

The module we want to use is not found in the development environment that we specified in the `Dockerfile`.

We then modify the `Dockerfile` to add the new package as well

```Dockerfile
FROM node
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

WORKDIR /dev-dependencies
RUN npm install figlet
RUN npm install cli

WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]
```

We build the new development environment

```
docker build -t myapp_dev_environment .
```

And run again the application using this new image

```bash
$ docker run --rm -it -v $PWD/app:/app myapp_dev_environment main.js
  _   _      _ _         ____                  _ _ 
 | | | | ___| | | ___   |  _ \  ___  __ _ _ __| | |
 | |_| |/ _ \ | |/ _ \  | | | |/ _ \/ _` | '__| | |
 |  _  |  __/ | | (_) | | |_| |  __/ (_| | |  |_|_|
 |_| |_|\___|_|_|\___/  |____/ \___|\__,_|_|  (_|_)
```

The application works. `cli` was successfully included in `main.js`.

## Map users of container and host

One issue with the approach we followed above is that the command execution in the container is running with `root`. We see the following in our `host` (where we are actually `user`)

```ls
$ ls -l
total 24
-rw-r--r--  1 user user  242 Feb  1 20:13 main.js
drwxr-xr-x 16 root root 4096 Feb  1 20:10 node_modules
-rw-r--r--  1 root root   72 Feb  1 20:13 package.json
-rw-r--r--  1 root root 8907 Feb  1 20:13 package-lock.json

```

Up to now we did not want to add many lines to the `Dockerfile` to allow us to focus on the main concepts. Now is the time to make it more dirty.

Recall that we want to use our `Docker` environment to develop our application and not just to run it. Any file created by the container inside `/app` must be owned by the user we are using in our `host`.

We want that the user that performs operations related to our application inside the container (installing modules, creating new files, and more) has our same `user` and `group` id that we have in `host`. With this if the user in the container creates any file into the volume bound with `$PWD/app` of the `host` then we will see that file as owned by us (`user`) into the filesystem of the `host`.

What we want, is to have a cousin user (with name `a-more-secure-developer`) that exists in the context of the container but shares with us the same user and group id that we have in our `host`. Whatever `a-more-secure-developer` does in `/app` of the container it looks like as if we were doing it into `$PWD/app` of the `host`.

Furthermore we want to give `a-more-secure-developer` `sudo` capabilities inside the container. This is our development environment, we would like to relax restrictions, we want to play with stuff (with caution) that may come from out there. For explanatory sake we are allowing the user to have `sudo` capabilities without a password required.

With this in mind, we change the `Dockerfile` content with the following

```Dockerfile
FROM node
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

ARG USER_UID
ARG USER_GID

# create a new group with provided USER_GID (force override if already existing)
RUN groupadd --gid $USER_GID a-more-secure-developer -f

# if a user with USER_UID already exists, assign a new ID to that user
# assuming `3333` is not an id already taken
RUN usermod -u 3333 `id -un $USER_UID` 2>/dev/null

RUN useradd --uid $USER_UID --gid $USER_GID -m a-more-secure-developer

RUN apt-get update \
    && apt-get install -y sudo \
    && echo a-more-secure-developer ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/a-more-secure-developer \
    && chmod 0440 /etc/sudoers.d/a-more-secure-developer


RUN mkdir /dev-dependencies \
    && chown -R $USER_UID:$USER_GID /dev-dependencies

RUN mkdir /app \
    && chown -R $USER_UID:$USER_GID /app

USER a-more-secure-developer

WORKDIR /dev-dependencies
RUN npm install figlet
RUN npm install cli

WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]

```

We build it

```
 docker build -t myapp_dev_environment --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) .
```

We remove any artifacts that was created in previous runs.

From 

```
$ ls -l app/
total 24
-rw-r--r--  1 user user  242 Feb  1 20:19 main.js
drwxr-xr-x 16 root root 4096 Feb  1 20:10 node_modules
-rw-r--r--  1 root root   72 Feb  1 20:13 package.json
-rw-r--r--  1 root root 8907 Feb  1 20:13 package-lock.json
```

we pass to 

```
$ ls -l app/
total 4
-rw-r--r-- 1 user user 242 Feb  1 17:19 main.js
```

otherwise when binding the volume there will be permission issues.

We now run

```bash
$ docker run --rm -it -v $PWD/app:/app myapp_dev_environment main.js
  _   _      _ _         ____                  _ _ 
 | | | | ___| | | ___   |  _ \  ___  __ _ _ __| | |
 | |_| |/ _ \ | |/ _ \  | | | |/ _ \/ _` | '__| | |
 |  _  |  __/ | | (_) | | |_| |  __/ (_| | |  |_|_|
 |_| |_|\___|_|_|\___/  |____/ \___|\__,_|_|  (_|_)
                                                   
```

We see that now `node` artifacts that were created by `a-more-secure-developer` into the context of the container are shown inside the filesystem of our `host` as owned by us (`user`)

```
$ ls -l app/
total 24
-rw-r--r--  1 user user  242 Feb  1 20:19 main.js
drwxr-xr-x 16 user user 4096 Feb  1 21:31 node_modules
-rw-r--r--  1 user user   72 Feb  1 21:31 package.json
-rw-r--r--  1 user user 8907 Feb  1 21:31 package-lock.json

```

## Play with the container at runtime

Now we have an image that created a development environment.

If want to play at runtime with such an environment we can launch the container interactively.

With the following we override the `entrypoint` specified by the `Docker` image and replace it with `/bin/bash`. With this we are able to spawn a shell into the container context

```
$ docker run --rm -it -v $PWD/app:/app --entrypoint /bin/bash myapp_dev_environment
a-more-secure-developer@1e8b60d512e7:/app$ 
```

We see that in the container we have `sudo` capabilities

```
a-more-secure-developer@1e8b60d512e7:/app$ sudo whoami
root
```
We can play with our development environment as we like!

Moreover, we can change the content of the files inside our `host` under `$PWD/app` and see the effects reflected inside the `/app` directory of the container.

We add the following line to `$PWD/app/main.js` into our `host`

```
var node-emoji = require("node-emoji");
```

We check the content of `main.js` in the filesystem of our `host`

```
$ head -n 3 app/main.js 
var figlet = require('figlet');
var cli = require('cli');
var node-emoji = require("node-emoji");
```

We then do the same check inside the container

```
a-more-secure-developer@1e8b60d512e7:/$ head -n 3 app/main.js 
var figlet = require('figlet');
var cli = require('cli');
var node-emoji = require("node-emoji");
```

we see that changes happening in the `host` are reflected inside the container.

Therefore, we can use our `host` to write code (using our IDE of choice for instance) and use the container to actually run the code!

We try to run the new `main.js` inside the container

```
a-more-secure-developer@1e8b60d512e7:/app$ node main.js 
node:internal/modules/cjs/loader:1042
  throw err;
  ^

Error: Cannot find module 'node-emoji'
```

As expected we get an error for the new `node-emoji` module that we try to import.

We have to do `npm install node-emoji` to get the package

```
a-more-secure-developer@1e8b60d512e7:/app$ npm install node-emoji
```

We then run the application again

```bash
a-more-secure-developer@1e8b60d512e7:/app$ node main.js 
  _   _      _ _         ____                  _ _ 
 | | | | ___| | | ___   |  _ \  ___  __ _ _ __| | |
 | |_| |/ _ \ | |/ _ \  | | | |/ _ \/ _` | '__| | |
 |  _  |  __/ | | (_) | | |_| |  __/ (_| | |  |_|_|
 |_| |_|\___|_|_|\___/  |____/ \___|\__,_|_|  (_|_)
                                                   
```

If `node-emoji` is expected to be part of our actual development environment then `npm install node-emoji` must be added to the `Dockerfile`. If we are just testing `node-emoji` and we do not want to use it anymore then there is no need to have it in our environment.

Indeed if there is no instruction to install the `node-emoji` package inside the `Dockerfile` then when we run again our `main.js`, using another container based on the same `myapp_dev_environment` image, we get the following


```
$ docker run --rm -it -v $PWD/app:/app myapp_dev_environment main.js
node:internal/modules/cjs/loader:1042
  throw err;
  ^

Error: Cannot find module 'node-emoji'

```

The `node-emoji` package was installed at runtime (inside an interactive session) with a container.

Actual the removal of the package is forced by us. When we do `docker run --rm -it -v $PWD/app:/app myapp_dev_environment main.js` we make our `entrypoint.sh` execute. This contains the following two commands

```
rm -rf /app/node_modules
rm -f /app/{package,package-lock}.json
```

They are intended to clean from `/app` any `node` artifacts that may have been created by a container at runtime.

We clean them, because we want that the environment specified in the `Dockerfile` has to be in a one to one relationship with the development environment we actually want.

If we comment out these two lines of `entrypoint.sh` then any package installed by a container at runtime (under `/app`) persists even after a new `docker run` is executed. This is due to the fact that the `/app` folder of the container is mapped with `$PWD/app` of the `host`. If we run `npm install` inside an interactive container then changes to `node_modules`, `package.json` and `package-lock.json` are persisted.

If you actually want this to be the case then you can comment out these two lines.


## Integration via VS CODE

We usually write code inside an IDE that is installed in the `host`. This means that when we click `run program` in the IDE, this searches (by default) for compilers or interpreters that are installed on the `host`. To change the execution context we have to tell the IDE to use the compiler/interpreter that is to be found inside a container and not the one available from the `host`.

But think about the `node` application we are considering in this article. We do not want to run it only, we would also like to debug it to speed up our development activities.

But if the `node` interpreter is expected to be found in a containerized environment then any interactive debug in the IDE may be impaired. Furthermore, the IDE may not be able to provide suggestions and information about the objects we are using in the code (like when we install specific plugins for the language). We write code in the `host` filesystem but the execution context is inside the container!

If the container is spawn by the IDE only when we click on either `run` or `debug` actions how can the IDE follow the code we write? It will complain a lot while we write the code. It is understandable, it cannot resolve dependencies. This information is in the container, but they will be available to the IDE only when we click `run program`. To solve this we should make the IDE think that its context is the one of the container not the one of the `host`.

We present the case of how we can achieve this in `VS CODE` using the `Dev Containers` extension.

We have `VS CODE` installed in the `host` but when we attach it to a running container it is like a new instance of `VS CODE` is launched but with the context of the container instead of the `host`.

We install the extension

![dev_containers](../img/dev_containers.png)

We then run a container out of `myapp_dev_environment` image. We want this container to keep running in the background. The IDE has to attach to it.

```
docker run --rm -d -t -v $PWD/app:/app --name container_development myapp_dev_environment
```

`--name` to assign the container a name

`-d` is to run the container in `detached` mode

`-t` spawns a pseudo `tty` terminal

The combination of `-d` and `-t` allows the container to keep running in the background.

```
$ docker ps
CONTAINER ID   IMAGE                   COMMAND            CREATED         STATUS         PORTS     NAMES
54960c6ed1e3   myapp_dev_environment   "/entrypoint.sh"   3 minutes ago   Up 3 minutes             container_development

```

![dev_container_in_vs_code](../img/dev_container_in_vs_code.png)


We right-click on the container shown in `VS CODE` and then `Attach to Container`.

A new instance of `VS CODE` is spawn and the context is the one of the container as can be seen from the bottom left of the following image


![inside_running_container](../img/inside_running_container.png)

As shown in the above image the terminal provided by this new instance of `VS STUDIO` is the one of the container.

We can run the application directly in `VS CODE`

![run_app_inside_container_from_vm](../img/run_app_inside_container_from_vm.png)

We can also debug

![debug_in_vscode](../img/debug_in_vscode.png)

Happy coding!
