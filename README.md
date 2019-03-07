#### Supported tags and respective `Dockerfile` links

* `jtreminio/volsync:latest` ([Dockerfile](https://github.com/jtreminio/volsync/blob/master/Dockerfile))

[Docker Hub homepage](https://hub.docker.com/r/jtreminio/volsync/tags/)

#### [This README best viewed on Github for formatting](https://github.com/jtreminio/volsync/blob/master/README.md)

## What is this image for

MacOS users are well aware that Docker for Mac has slow volume sharing. This image aims to alleviate (not completely solve) the slowness by moving the responsibility of syncing shared volumes away from the app containers themselves and to a dedicated syncer.

`volsync` uses `rsync` to copy from your container's volume to your host directory. The process is delayed (default: 30 seconds) and uses very little resources. This tool is best used for volumes that your container process requires be up to date ASAP, but your host may not particularly care about being completely synchronized immediately.

Examples of these types of volumes are package manager directories like `node_modules` in Javascript's NPM/Yarn or `vendor` in PHP's composer.

For PHP, if you use a framework like Symfony you would want to use `volsync` for your `cache` and `vendor` directories.

As you would not be actively editing any files in these directories, a slight delay in syncing from container to host is acceptable and beneficial to speed of development.

This tool is not recommended for production use, as it is squarely aimed at speeding up your development process.

## Example use-case

### Javascript Project

If your project is Javascript-based and you are using NPM/Yarn your directory structure would look like this:

    $ tree .
    .
    ├── node_modules
    │   ├── express
    │   ├── react
    │   └── [etc]
    ├── src
    │   ├── app.js
    │   └── [etc]
    ├── docker-compose.yml
    ├── package.json
    └── [etc]

In this scenario you are working on files in `src` or the root directory. You are not actively editing any files within `node_modules` but your IDE wants to see the packages installed there so it can provide typehinting.

As contents within `node_modules` are not continuously changed it is safe to delay syncing from the container to the host.

### PHP Project

If your project is PHP-based and you are using Composer your directory structure would look like this:

    $ tree .
    .
    ├── app
    │   ├── cache
    │   └── [etc]
    ├── composer.json
    ├── docker-compose.yml
    ├── public
    ├── src
    ├── vendor
    └── [etc]

In this scenario you are working on files in `src` or the root directory. You are not actively editing any files within `app/cache` or `vendor` but your IDE wants to see the contents and packages installed there so it can provide typehinting.

As contents within `app/cache` are machine-generated and you are not actively editing them, and as contents within `vendor` are not continuously changed it is safe to delay syncing from the container to the host.

## How this tool works

This tool synchronizes directories between your host and container, avoiding slowing down your main container service.

For example, your `docker-compose.yml` file may look like this:

    version: '3.2'
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www

To use this tool you would tell Docker not to sync your host's `node_modules` with the container. Instead, it should use a named volume, like so:

    version: '3.2'
    volumes:
        modules:
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www
                - modules:/var/www/node_modules

Your container's `/var/www/node_modules` now points to the named `modules` volume and not the actual `node_modules` directory on your host. Any hanges made within your container's `/var/www/node_modules` will not be synced to your host's `node_modules` directory.

You can now tell `volsync` to manage the syncing for you:

    version: '3.2'
    volumes:
        modules:
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www
                - modules:/var/www/node_modules
        volsync:
            image: jtreminio/volsync
            volumes:
                - modules:/vol/container/node_modules
                - ./www/node_modules/:/vol/host/node_modules

Now any changes made in your container's `/var/www/node_modules` _will be rsynced_ to your host's `node_modules` directory, every 30 seconds.

If you run `yarn` in your container then contents are immediately available by your container's Javascript service, and your host will see the contents after a short delay.

Since `node_modules` directory can easily contain well over 30,000 files nested many directories deep. Removing the need to immediately sync between your container -> host _and_ between host -> container reduces response times in your applications immensely.

A single `volsync` container can also handle syncing multiple containers:

    version: '3.2'
    volumes:
        modules:
        cache:
        vendor:
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www
                - modules:/var/www/node_modules
        node:
            image: php
            volumes:
                - $PWD:/var/www
                - cache:/var/www/app/cache
                - vendor:/var/www/vendor
        volsync:
            image: jtreminio/volsync
            volumes:
                - modules:/vol/container/node_modules
                - ./www/node_modules/:/vol/host/node_modules
                
                - cache:/vol/container/cache
                - ./www/app/cache/:/vol/host/cache
                
                - vendor:/vol/container/vendor
                - ./www/vendor/:/vol/host/vendor

## Naming requirements

Your project does not need any changes to make this tool work, but you _must_ follow a naming convention for the `jtreminio/volsync` container's volumes for this to work.

The tool scans its internal `/vol/container` for directories to sync. It then syncs to same-named directories in `/vol/host`.

For example, 

    - modules:/vol/container/node_modules
    - ./www/node_modules/:/vol/host/node_modules

`volsyn` scans `/vol/container` and sees `node_modules`, then syncs to `/vol/host/node_modules`.

## Changing sync time, user/group ID

You can change how often syncing occurs by setting the TIME variable:

    volsync:
        image: jtreminio/volsync
        environment:
            - TIME=5
        volumes:
            - modules:/vol/container/node_modules
            - ./www/node_modules/:/vol/host/node_modules

The tool will run every 5 seconds.

You can also change the user ID and group ID of the contents copied _to your host_:

    volsync:
        image: jtreminio/volsync
        environment:
            - UID=1000
            - GID=1000
        volumes:
            - modules:/vol/container/node_modules
            - ./www/node_modules/:/vol/host/node_modules

All directories and files will be owned by `1000:1000` on your host, even if owned by another user/group within the container.

## Guide to mapping volumes

At first, it can be confusing to figure out how to setup your volumes. Here is your initial `docker-compose.yml`:

    version: '3.2'
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www
                
this is the map:

    version: '3.2'
    volumes:
        ${NAMED_VOLUME}:
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www
                - ${NAMED_VOLUME}:${CONTAINER_DIRECTORY}
        volsync:
            image: jtreminio/volsync
            volumes:
                - ${NAMED_VOLUME}:/vol/container/${VOLSYNC_NAME}
                - ${HOST_DIRECTORY}:/vol/host/${VOLSYNC_NAME}

Both your service (`node`) and `volsync` must see `NAMED_VOLUME`.

`CONTAINER_DIRECTORY` is where your container sees the contents.

`HOST_DIRECTORY` is the directory on your host that you want to delay-sync with `volsync`.

`VOLSYNC_NAME` must be identical and is the two paths `volsync` internally syncs between.

Thus, the above turns into:

    version: '3.2'
    volumes:
        modules:
    services:
        node:
            image: node:9-alpine
            volumes:
                - $PWD:/var/www
                - modules:/var/www/node_modules
        volsync:
            image: jtreminio/volsync
            volumes:
                - modules:/vol/container/node_modules
                - ./www/node_modules/:/vol/host/node_modules
