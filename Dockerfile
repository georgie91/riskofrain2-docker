FROM rustagainshell/rash AS rash
FROM steamcmd/steamcmd AS vanilla
MAINTAINER Laura Demkowicz-Duffy <fragsoc@yusu.org>

USER root
WORKDIR /
RUN apt-get update && \
    apt-get install -y wine-stable xvfb lib32gcc1

ARG APPID=1180760
ARG STEAM_BETAS
ARG UID=999
ARG GID=999
ARG GAME_PORT=27015
ARG STEAM_PORT=27016

ENV INSTALL_LOC="/ror2"
ENV HOME=${INSTALL_LOC}
ENV GAME_PORT=${GAME_PORT}
ENV STEAM_PORT=${STEAM_PORT}

RUN mkdir -p $INSTALL_LOC && \
    groupadd -g $GID ror2 && \
    useradd -m -s /bin/false -u $UID -g $GID ror2 && \
    # Setup directory structure and permissions
    mkdir -p $INSTALL_LOC && \
    chown -R ror2:ror2 $INSTALL_LOC

USER ror2

# Install the ror2 server
RUN steamcmd \
        +login anonymous \
        +force_install_dir $INSTALL_LOC \
        +@sSteamCmdForcePlatformType windows \
        +app_update $APPID $STEAM_BETAS validate \
        +app_update 1007 validate \
        +quit

# Config setup
COPY --from=rash /bin/rash /usr/bin/rash
COPY server.cfg.j2 /server.cfg
COPY docker-entrypoint.rh /docker-entrypoint.rh

# I/O
EXPOSE $GAME_PORT/udp $STEAM_PORT/udp
WORKDIR $INSTALL_LOC
ENTRYPOINT ["rash", "/docker-entrypoint.rh"]

FROM debian:stretch-slim AS curl

RUN apt-get update && \
    apt-get install -y unzip curl

ARG BEPINEX_VERSION=5.3.1
ARG R2API_VERSION=2.5.14

WORKDIR /tmp
RUN curl -L -o ./r2api.zip \
        https://thunderstore.io/package/download/tristanmcpherson/R2API/${R2API_VERSION}/ && \
    curl -L -o ./bepinexpack.zip \
        https://thunderstore.io/package/download/bbepis/BepInExPack/${BEPINEX_VERSION}/
RUN mkdir -p bepinexpack r2api && \
    unzip ./bepinexpack.zip -d bepinex && \
    unzip ./r2api.zip -d r2api

FROM vanilla AS bepapi

ENV MODS_LOC="/plugins"

USER root
RUN mkdir -p $MODS_LOC && \
    chown -R ror2:ror2 $MODS_LOC

USER ror2
COPY --from=curl --chown=ror2 /tmp/bepinex/BepInExPack/BepInEx $INSTALL_LOC/BepInEx
COPY --from=curl --chown=ror2 /tmp/bepinex/BepInExPack/doorstop_config.ini $INSTALL_LOC
COPY --from=curl --chown=ror2 /tmp/bepinex/BepInExPack/winhttp.dll $INSTALL_LOC
RUN rm -r $INSTALL_LOC/BepInEx/plugins && \
    ln -s $MODS_LOC $INSTALL_LOC/BepInEx/plugins

COPY --from=curl --chown=ror2 /tmp/r2api/plugins $MODS_LOC/
COPY --from=curl --chown=ror2 /tmp/r2api/monomod $INSTALL_LOC/BepInEx/monomod/

VOLUME $MODS_LOC
