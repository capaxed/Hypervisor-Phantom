#!/usr/bin/env bash

# https://github.com/Frogging-Family/linux-tkg

[[ -z "$DISTRO" || -z "$LOG_FILE" ]] && exit 1

source "./utils/prompter.sh"
source "./utils/formatter.sh"
source "./utils/packages.sh"

declare -r CPU_VENDOR=$(case "$VENDOR_ID" in
  *AuthenticAMD*) echo "svm" ;;
  *GenuineIntel*) echo "vmx" ;;
  *) fmtr::error "Unknown CPU vendor."; exit 1 ;;
esac)

readonly SRC_DIR="src"
readonly TKG_URL="https://github.com/Frogging-Family/linux-tkg.git"
readonly TKG_DIR="linux-tkg"
readonly TKG_CFG_DIR="../../$SRC_DIR/linux-tkg/customization.cfg"
readonly PATCH_DIR="../../patches/Kernel"
readonly KERNEL_MAJOR="6"
readonly KERNEL_MINOR="14"
readonly KERNEL_PATCH="latest" # Set as "-latest" for linux-tkg
readonly KERNEL_VERSION="${KERNEL_MAJOR}.${KERNEL_MINOR}-${KERNEL_PATCH}"
readonly KERNEL_USER_PATCH="../../patches/Kernel/zen-kernel-${KERNEL_MAJOR}.${KERNEL_MINOR}-${KERNEL_PATCH}-${CPU_VENDOR}.mypatch"

acquire_tkg_source() {

  mkdir -p "$SRC_DIR" && cd "$SRC_DIR"

  if [ -d "$TKG_DIR" ]; then
    if [ -d "$TKG_DIR/.git" ]; then
      fmtr::warn "Directory $TKG_DIR already exists and is a valid Git repository."
      if ! prmt::yes_or_no "$(fmtr::ask 'Delete and re-clone the linux-tkg source?')"; then
        fmtr::info "Keeping existing directory; Skipping re-clone."
        cd "$TKG_DIR" || { fmtr::fatal "Failed to change to TKG directory after cloning: $TKG_DIR"; exit 1; }
        return
      fi
    else
      fmtr::warn "Directory $TKG_DIR exists but is not a valid Git repository."
      if ! prmt::yes_or_no "$(fmtr::ask 'Delete and re-clone the linux-tkg source?')"; then
        fmtr::info "Keeping existing directory; Skipping re-clone."
        cd "$TKG_DIR" || { fmtr::fatal "Failed to change to TKG directory after cloning: $TKG_DIR"; exit 1; }
        return
      fi
    fi
    rm -rf "$TKG_DIR" || { fmtr::fatal "Failed to remove existing directory: $TKG_DIR"; exit 1; }
    fmtr::info "Directory purged"
  fi

  fmtr::info "Cloning linux-tkg repository..."
  git clone --single-branch --depth=1 "$TKG_URL" "$TKG_DIR" &>> "$LOG_FILE" || { fmtr::fatal "Failed to clone repository."; exit 1; }
  cd "$TKG_DIR" || { fmtr::fatal "Failed to change to TKG directory after cloning: $TKG_DIR"; exit 1; }
  fmtr::info "TKG source successfully acquired."

  grep -RIl '\-Werror' "$(pwd)" | while read -r file; do
      echo "$file"
      sed -i -e 's/-Werror=/\-W/g' -e 's/-Werror-/\-W/g' -e 's/-Werror/\-W/g' "$file"
  done &>> "$LOG_FILE" || { fmtr::fatal "Failed to disable warnings-as-errors!"; exit 1; }

}


select_distro() {

  while true; do
    clear; fmtr::info "Please select your Linux distribution:

  1) Arch    3) Debian  5) Suse    7) Generic
  2) Ubuntu  4) Fedora  6) Gentoo
    "

    local choice="$(prmt::quick_prompt '  Enter your choice [1-7]: ')"

    case "$choice" in
        1) distro="Arch" ;;
        2) distro="Ubuntu" ;;
        3) distro="Debian" ;;
        4) distro="Fedora" ;;
        5) distro="Suse" ;;
        6) distro="Gentoo" ;;
        7) distro="Generic" ;;
        *)
            clear; fmtr::error "Invalid option, please try again."
            prmt::quick_prompt "$(fmtr::info 'Press any key to continue...')"
            continue
            ;;
    esac

    echo ""; fmtr::info "Selected Linux distribution: $distro"
    break
  done

}


modify_customization_cfg() {

  ####################################################################################################
  ####################################################################################################

  fmtr::info "This patch enables corrected IOMMU grouping on
      motherboards with poor PCI IOMMU grouping."
  if prmt::yes_or_no "$(fmtr::ask 'Apply ACS override bypass Kernel patch?')"; then
      acs="true"
  else
      acs="false"
  fi

  ####################################################################################################
  ####################################################################################################

  while true; do

    if [[ "$CPU_VENDOR" == "svm" ]]; then
      vendor="AMD"
      fmtr::info "Detected CPU Vendor: $vendor

  Please select your Intel CPU microarchitecture code name:

  1) k8         5) bobcat      9) steamroller  13) zen3
  2) k8sse3     6) jaguar      10) excavator   14) zen4
  3) k10        7) bulldozer   11) zen         15) zen5
  4) barcelona  8) piledriver  12) zen2        16) Automated (not recommended)
      "
      read -p "  Enter your choice [1-16]: " choice
      case "$choice" in
        1) selected="k8" ;;
        2) selected="k8-sse3" ;;
        3) selected="k10" ;;
        4) selected="barcelona" ;;
        5) selected="bobcat" ;;
        6) selected="jaguar" ;;
        7) selected="bulldozer" ;;
        8) selected="piledriver" ;;
        9) selected="steamroller" ;;
        10) selected="excavator" ;;
        11) selected="znver1" ;;
        12) selected="znver2" ;;
        13) selected="znver3" ;;
        14) selected="znver4" ;;
        15) selected="znver5" ;;
        16) selected="native" ;;
        *)
          clear; fmtr::error "Invalid option, please try again."
          prmt::quick_prompt "$(fmtr::info 'Press any key to continue...')"
          continue
          ;;
      esac

    elif [[ "$CPU_VENDOR" == "vmx" ]]; then
      vendor="Intel"
      fmtr::info "Detected CPU Vendor: $vendor

  Please select your Intel CPU microarchitecture code name:

  1) mpsc         8) ivybridge    15) icelake_server  22) rocketlake
  2) atom         9) haswell      16) goldmont        23) alderlake
  3) core2        10) broadwell   17) goldmontplus    24) raptorlake
  4) nehalem      11) skylake     18) cascadelake     25) meteorlake
  5) westmere     12) skylakex    19) cooperlake      26) automated (not recommended)
  6) silvermont   13) cannonlake  20) tigerlake
  7) sandybridge  14) icelake     21) sapphirerapids
      "
      read -p "  Enter your choice [1-26]: " choice
      case "$choice" in
        1) selected="mpsc" ;;
        2) selected="atom" ;;
        3) selected="core2" ;;
        4) selected="nehalem" ;;
        5) selected="westmere" ;;
        6) selected="silvermont" ;;
        7) selected="sandybridge" ;;
        8) selected="ivybridge" ;;
        9) selected="haswell" ;;
        10) selected="broadwell" ;;
        11) selected="skylake" ;;
        12) selected="skylakex" ;;
        13) selected="cannonlake" ;;
        14) selected="icelake" ;;
        15) selected="icelake_server" ;;
        16) selected="goldmont" ;;
        17) selected="goldmontplus" ;;
        18) selected="cascadelake" ;;
        19) selected="cooperlake" ;;
        20) selected="tigerlake" ;;
        21) selected="sapphirerapids" ;;
        22) selected="rocketlake" ;;
        23) selected="alderlake" ;;
        24) selected="raptorlake" ;;
        25) selected="meteorlake" ;;
        26) selected="native" ;;
        *)
          clear; fmtr::error "Invalid option, please try again."
          prmt::quick_prompt "$(fmtr::info 'Press any key to continue...')"
          ;;
      esac

    else
      fmtr::warn "Unsupported or undefined CPU_VENDOR: $CPU_VENDOR"
      exit 1
    fi

    break
  done

  ####################################################################################################
  ####################################################################################################

  if output=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep supported); then
      :
  elif output=$(/lib64/ld-linux-x86-64.so.2 --help 2>/dev/null | grep supported); then
      :
  fi

  highest=0

  while IFS= read -r line; do
      if [[ $line =~ x86-64-v([123]) ]]; then
          version="${BASH_REMATCH[1]}"
          if (( version > highest )); then
              highest=$version
          fi
      fi
  done <<< "$output"

  x86_version=$highest

  ####################################################################################################
  ####################################################################################################

  declare -A config_values=(
      [_distro]="$distro"
      [_version]="$KERNEL_VERSION"
      [_menunconfig]="false"
      [_diffconfig]="false"
      [_cpusched]="eevdf"
      [_compiler]="gcc"
      [_sched_yield_type]="0"
      [_rr_interval]="2"
      [_tickless]="1"
      [_acs_override]="$acs"
      [_processor_opt]="$selected"
      [_x86_64_isalvl]="$highest"
      [_timer_freq]="1000"
      [_user_patches_no_confirm]="true"
  )

  for key in "${!config_values[@]}"; do
      sed -i "s|$key=\"[^\"]*\"|$key=\"${config_values[$key]}\"|" "$TKG_CFG_DIR" &>> "$LOG_FILE"
  done

}

patch_kernel() {

  mkdir -p "linux${KERNEL_MAJOR}${KERNEL_MINOR}-tkg-userpatches"
  cp "${KERNEL_USER_PATCH}" "linux${KERNEL_MAJOR}${KERNEL_MINOR}-tkg-userpatches"

}

arch_distro() {

  clear; makepkg -C -si --noconfirm

  if prmt::yes_or_no "$(fmtr::ask 'Would you like to add a systemd-boot entry for this kernel?')"; then
    systemd-boot_boot_entry_maker
  else
    fmtr::info "Skipping systemd-boot entry creation."
  fi

}

other_distro() {

  clear; sudo ./install.sh install

  if prmt::yes_or_no "$(fmtr::ask 'Would you like to add a systemd-boot entry for this kernel?')"; then
    systemd-boot_boot_entry_maker
  else
    fmtr::info "Skipping systemd-boot entry creation."
  fi

}

systemd-boot_boot_entry_maker() {

  declare -a SDBOOT_CONF_LOCATIONS=(
    "/boot/loader/entries"
    "/boot/efi/loader/entries"
    "/efi/loader/entries"
  )

  local ENTRY_NAME="HvP-RDTSC"
  local TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
  local ROOT_DEVICE=$(sudo findmnt -no SOURCE /)
  local ROOTFSTYPE=$(sudo findmnt -no FSTYPE /)
  local CLEANED_DEVICE="${ROOT_DEVICE%%[*}"
  local PARTUUID=$(sudo blkid -s PARTUUID -o value "$CLEANED_DEVICE")

  if [[ -z "$PARTUUID" ]]; then
    fmtr::error "Unable to determine PARTUUID for root device ($ROOT_DEVICE)."
    return 1
  fi

  local BOOT_ENTRY_CONTENT=$(cat <<EOF
# Created by: Hypervisor-Phantom
# Created on: $TIMESTAMP
title   HvP (RDTSC Patch)
linux   /vmlinuz-linux$KERNEL_MAJOR$KERNEL_MINOR-tkg-eevdf
initrd  /initramfs-linux$KERNEL_MAJOR$KERNEL_MINOR-tkg-eevdf.img
options root=PARTUUID=$PARTUUID rw rootfstype=$ROOTFSTYPE
EOF
)

  local FALLBACK_BOOT_ENTRY_CONTENT=$(cat <<EOF
# Created by: Hypervisor-Phantom
# Created on: $TIMESTAMP
title   HvP (RDTSC Patch - Fallback)
linux   /vmlinuz-linux$KERNEL_MAJOR$KERNEL_MINOR-tkg-eevdf
initrd  /initramfs-linux$KERNEL_MAJOR$KERNEL_MINOR-tkg-eevdf-fallback.img
options root=PARTUUID=$PARTUUID rw rootfstype=$ROOTFSTYPE
EOF
)

  for ENTRY_DIR in "${SDBOOT_CONF_LOCATIONS[@]}"; do
    if [[ -d "$ENTRY_DIR" ]]; then
      echo "$BOOT_ENTRY_CONTENT" | sudo tee "$ENTRY_DIR/$ENTRY_NAME.conf" &>> "$LOG_FILE"
      echo "$FALLBACK_BOOT_ENTRY_CONTENT" | sudo tee "$ENTRY_DIR/$ENTRY_NAME-fallback.conf" &>> "$LOG_FILE"
      if [[ $? -eq 0 ]]; then
        fmtr::info "Boot entries written to: $ENTRY_DIR/$ENTRY_NAME.conf and $ENTRY_DIR/$ENTRY_NAME-fallback.conf"
        return 0
      else
        fmtr::error "Failed to write boot entries to: $ENTRY_DIR/$ENTRY_NAME.conf and $ENTRY_DIR/$ENTRY_NAME-fallback.conf"
        return 1
      fi
    fi
  done

  fmtr::error "No valid systemd-boot entry directory found."
  return 1

}

acquire_tkg_source
select_distro
modify_customization_cfg
patch_kernel

if [ "$distro" == "Arch" ]; then
    arch_distro
else
    other_distro
fi
