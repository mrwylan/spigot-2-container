# spigot-2-container

Building and provisioning the latest SpigotMC as a container image.

## intent

Use this dockerfile as an idea for a nice multi stage docker build.

## licence

By building this container - You are consuming public content from the internet that brings it's own licences.
You have to build your container image by Your own. There will be no public image available.

## see

https://www.spigotmc.org/threads/spigot.330107/#post-3082540

https://account.mojang.com/terms

# Step by step

1. clone this repository

2. optional: copy your server files (ops.json, server.properties) to the serverdata folder

3. optional: your level folders to the leveldata folder

4. build the image with docker: e.g.

´´´
docker build -t spigot-2-container:1.14.4 --build-arg world=ExodusWorld --build-arg rev=1.14.4 . 
´´´

## build-arg
* world = the name of the level to play
* rev = available MC version for the build tool
