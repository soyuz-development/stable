# Use ubuntu's rolling tag as the base image
FROM ubuntu:rolling AS base


FROM base AS plymouth-builder

#install deps related to plymouth
RUN <<-EOT
    apt-get update -y
    apt-get install --no-install-recommends -y meson git ca-certificates
EOT

WORKDIR /branding

RUN <<-EOT
    mkdir -p src_dir target_dir
EOT

WORKDIR /branding/src_dir

RUN <<-EOT
    git clone --single-branch -b main https://github.com/soyuz-development/plymouth-theme.git
    cd plymouth-theme
    meson setup builddir
    cd builddir
    ninja install
EOT


FROM base AS builder

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

COPY --chmod=755 <<-EOF /usr/share/glib-2.0/schemas/99_soyuz.gschema.override
[org.gnome.login-screen]
logo='/usr/share/plymouth/themes/soyuz-bgrt/watermark.png'
EOF

RUN <<-EOT
    apt-get update -y
    apt-get dist-upgrade -y
EOT

#install kernel+grub+plymouth 
RUN apt-get install -y linux-headers-generic linux-image-generic grub-efi plymouth sudo 

#install ubuntu-desktop with snap and flaptak as alternative package-managers
RUN apt-get install -y snapd flatpak ubuntu-desktop-minimal ubuntu-standard

#configure flatpak to use flathub as default remote
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#clear apt cache
RUN rm -rf /var/lib/apt/lists/* /var/log/alternatives.log /var/log/apt/history.log /var/log/apt/term.log /var/log/dpkg.log /etc/machine-id /var/lib/dbus/machine-id

#configure plymouth and hosts
COPY --from=plymouth-builder /usr/share/plymouth/themes/soyuz-bgrt/* /usr/share/plymouth/themes/soyuz-bgrt/

RUN <<-EOT
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/soyuz-bgrt/soyuz-bgrt.plymouth 200 
    update-initramfs -u
    deluser --remove-home ubuntu
EOT


FROM scratch
COPY --from=builder / /

ENTRYPOINT [ "/sbin/init" ]
CMD ["/bin/bash"]