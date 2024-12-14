# Use ubuntu's rolling tag as the base image
FROM ubuntu:rolling AS base


FROM base AS plymouth-builder

#install deps related to plymouth
RUN apt-get update && apt-get install --no-install-recommends -y meson git ca-certificates

WORKDIR /branding

RUN mkdir -p src_dir target_dir

WORKDIR /branding/src_dir

RUN git clone --single-branch -b main https://github.com/saturn-core/plymouth-theme.git && \
    cd plymouth-theme && \
    meson setup builddir && \
    cd builddir && \
    ninja install


FROM base AS builder

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

COPY 99_saturn.gschema.override /usr/share/glib-2.0/schemas/99_saturn.gschema.override

RUN apt-get update && apt-get dist-upgrade -y

#install kernel+grub+plymouth 
RUN apt-get install -y linux-headers-generic linux-image-generic grub-efi plymouth sudo perl

#install snap and flaptak as alternative package-managers
RUN apt-get install -y snapd flatpak 

#install packagekit, snap and flatpak bindings
RUN apt-get install -y --no-install-recommends packagekit python3-gi gir1.2-packagekitglib-1.0 gir1.2-snapd-2 gir1.2-flatpak-1.0

#configure flatpak to use flathub as default remote
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#clear apt cache
RUN rm -rf /var/lib/apt/lists/* /var/log/alternatives.log /var/log/apt/history.log /var/log/apt/term.log /var/log/dpkg.log /etc/machine-id /var/lib/dbus/machine-id

#configure plymouth and hosts
COPY --from=plymouth-builder /usr/share/plymouth/themes/saturn-bgrt/* /usr/share/plymouth/themes/saturn-bgrt/

RUN update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/saturn-bgrt/saturn-bgrt.plymouth 200  && \
    update-initramfs -u && \
    deluser --remove-home ubuntu

FROM scratch
COPY --from=builder / /

ENTRYPOINT [ "/sbin/init" ]
CMD ["/bin/bash"]
