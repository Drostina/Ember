FROM scratch AS ctx
COPY build_files /
COPY cosign.pub /cosign.pub
COPY system_files /system_files
COPY assets/branding/ember-symbol.svg /system_files/usr/share/icons/hicolor/scalable/apps/ember-logo-icon.svg

FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
