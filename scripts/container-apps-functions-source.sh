# -----------------------------------------------------------------------------
# This file is part of the GNU MCU Eclipse distribution.
#   (https://gnu-mcu-eclipse.github.io)
# Copyright (c) 2019 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build
# scripts. As the name implies, it should contain only functions and
# should be included with 'source' by the container build scripts.

# -----------------------------------------------------------------------------

# The surprise of this build was that building the cross guile requires
# a native guile; thus the need to build everything twice, first the
# native build, than the cross build.

# -----------------------------------------------------------------------------

function build_make()
{
  # https://www.gnu.org/software/make/
  # ftp://ftp.gnu.org/gnu/make/
  # http://ftpmirror.gnu.org/make/

  # 2016-06-11, "4.2.1"
  # 2020-01-20, "4.3" (fails with mings 7)

  MAKE_VERSION="$1"

  # The folder name as resulted after being extracted from the archive.
  MAKE_SRC_FOLDER_NAME="make-${MAKE_VERSION}"
  # The folder name  for build, licenses, etc.
  MAKE_FOLDER_NAME="${MAKE_SRC_FOLDER_NAME}"

  local make_archive_file_name="${MAKE_FOLDER_NAME}.tar.gz"

  local make_url="https://ftp.gnu.org/gnu/make/${make_archive_file_name}"

  local make_stamp_file_path="${INSTALL_FOLDER_PATH}/stamp-make-${MAKE_VERSION}-installed"
  if [ ! -f "${make_stamp_file_path}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${make_url}" "${make_archive_file_name}" \
      "${MAKE_SRC_FOLDER_NAME}" 

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${MAKE_FOLDER_NAME}"
      cd "${BUILD_FOLDER_PATH}/${MAKE_FOLDER_NAME}"

      xbb_activate
      xbb_activate_installed_bin

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running make configure..."

          # cd "${make_build_folder}"

          run_verbose bash "${SOURCES_FOLDER_PATH}/${MAKE_FOLDER_NAME}/configure" --help

          # CPPFLAGS="${XBB_CPPFLAGS} -I${SOURCES_FOLDER_PATH}/${MAKE_FOLDER_NAME}/glob"
          CPPFLAGS="${XBB_CPPFLAGS}"
          CFLAGS="${XBB_CFLAGS}"
          LDFLAGS="${XBB_LDFLAGS_APP} -static"
          if [ "${IS_DEVELOP}" == "y" ]
          then
            LDFLAGS+=" -v"
          fi

          export CPPFLAGS
          export CFLAGS
          export LDFLAGS

          echo
          run_verbose bash "${SOURCES_FOLDER_PATH}/${MAKE_FOLDER_NAME}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}/make-${MAKE_VERSION}"  \
            --build=${BUILD} \
            --host=${HOST} \
            --target=${TARGET} \
            \
            --without-guile \
            --without-libintl-prefix \
            --without-libiconv-prefix \
            ac_cv_dos_paths=yes \
            \
          cp "config.log" "${LOGS_FOLDER_PATH}/config-make-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-make-output.txt"

      fi

      (
        echo
        echo "Running make make..."

        # Build.
        run_verbose make -j ${JOBS}

        # Not on mingw.
        # run_verbose make check

        run_verbose make install-strip

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-make-output.txt"

      copy_license \
        "${SOURCES_FOLDER_PATH}/${MAKE_FOLDER_NAME}" \
        "${MAKE_FOLDER_NAME}"

    )

    touch "${make_stamp_file_path}"

  else
    echo "make already installed."
  fi
}

function build_busybox()
{
  # https://frippery.org/busybox/
  # https://github.com/rmyorston/busybox-w32

  # BUSYBOX_COMMIT=master
  # BUSYBOX_COMMIT="9fe16f6102d8ab907c056c484988057904092c06"
  # BUSYBOX_COMMIT="977d65c1bbc57f5cdd0c8bfd67c8b5bb1cd390dd"
  # BUSYBOX_COMMIT="9fa1e4990e655a85025c9d270a1606983e375e47"
  # BUSYBOX_COMMIT="c2002eae394c230d6b89073c9ff71bc86a7875e8"

  # Dec 9, 2017
  # BUSYBOX_COMMIT="096aee2bb468d1ab044de36e176ed1f6c7e3674d"

  # Apr 13, 2018
  # BUSYBOX_COMMIT="6f7d1af269eed4b42daeb9c6dfd2ba62f9cd47e4"

  # Apr 06, 2019
  # BUSYBOX_COMMIT="65ae5b24cc08f898e81b36421b616fc7fc25d2b1"

  # Dec 12, 2020
  # BUSYBOX_COMMIT="f902184fa8aa37b0ce8b725da5657ef2ed2005dd

  BUSYBOX_COMMIT="$1"

  BUSYBOX_ARCHIVE="${BUSYBOX_COMMIT}.zip"
  BUSYBOX_URL="https://github.com/rmyorston/busybox-w32/archive/${BUSYBOX_ARCHIVE}"

  BUSYBOX_SRC_FOLDER="busybox-w32-${BUSYBOX_COMMIT}"

  # Does not use configure and builds in the source folder.
  cd "${BUILD_FOLDER_PATH}"

  download_and_extract "${BUSYBOX_URL}" "${BUSYBOX_ARCHIVE}" "${BUSYBOX_SRC_FOLDER}"

  local busybox_stamp_file_path="${INSTALL_FOLDER_PATH}/stamp-busybox-${BUSYBOX_COMMIT}-installed"
  if [ ! -f "${busybox_stamp_file_path}" ]
  then
    (
      cd "${BUILD_FOLDER_PATH}"

      if [ ! -f "${BUILD_FOLDER_PATH}/${BUSYBOX_SRC_FOLDER}/.config" ]
      then
        (
          echo
          echo "Running BusyBox configure..."

          xbb_activate

          cd "${BUILD_FOLDER_PATH}/${BUSYBOX_SRC_FOLDER}"

          if [ ${TARGET_BITS} == "32" ]
          then
            # On 32-bit containers running on 64-bit systems, stat() fails with
            # 'Value too large for defined data type'.
            # The solution is to add _FILE_OFFSET_BITS=64.
            export HOST_EXTRACFLAGS="-D_FILE_OFFSET_BITS=64"
            make mingw32_defconfig \
              HOSTCC="gcc-xbb" \
              HOSTCXX="g++-xbb"
          elif [ ${TARGET_BITS} == "64" ]
          then
            make mingw64_defconfig \
              HOSTCC="gcc-xbb" \
              HOSTCXX="g++-xbb"
          fi

        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-busybox-output.txt"
      fi

      if [ ! -f "${BUILD_FOLDER_PATH}/${BUSYBOX_SRC_FOLDER}/busybox.exe" ]
      then
        (
          echo
          echo "Running BusyBox make..."

          xbb_activate

          export CFLAGS="${XBB_CFLAGS} -Wno-format-extra-args -Wno-format -Wno-overflow -Wno-unused-variable -Wno-implicit-function-declaration -Wno-unused-parameter -Wno-maybe-uninitialized -Wno-pointer-to-int-cast -Wno-strict-prototypes -Wno-old-style-definition -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-discarded-qualifiers -Wno-strict-prototypes -Wno-old-style-definition -Wno-unused-function -Wno-int-to-pointer-cast"
          export LDFLAGS="${XBB_LDFLAGS_APP} -static"

          if [ ${TARGET_BITS} == "32" ]
          then
            # Required since some of the host tools are built here.
            export HOST_EXTRACFLAGS="-D_FILE_OFFSET_BITS=64"
          fi

          cd "${BUILD_FOLDER_PATH}/${BUSYBOX_SRC_FOLDER}"

          make -j ${JOBS} \
            HOSTCC="gcc-xbb" \
            HOSTCXX="g++-xbb"

          mkdir -p "${INSTALL_FOLDER_PATH}/busybox-w32/bin"
          cp busybox.exe "${INSTALL_FOLDER_PATH}/busybox-w32/bin"
          
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-busybox-output.txt"
      fi

      copy_license \
        "${BUILD_FOLDER_PATH}/${BUSYBOX_SRC_FOLDER}" \
        "busybox-w32"

    )

    touch "${busybox_stamp_file_path}"

  else
    echo "BusyBox already installed."
  fi

}

function copy_binaries()
{
  mkdir -p "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}/bin"

  (
    xbb_activate

    echo
    echo "Copy make to install bin..."

    cp -v "${INSTALL_FOLDER_PATH}/make-${MAKE_VERSION}/bin/make.exe" \
      "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}/bin"

    ${CROSS_COMPILE_PREFIX}-strip \
      "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}/bin/make.exe"

    echo
    echo "Copy BusyBox to install bin..."

    cp -v "${INSTALL_FOLDER_PATH}/busybox-w32/bin/busybox.exe" \
      "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}/bin"

    ${CROSS_COMPILE_PREFIX}-strip \
      "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}/bin/busybox.exe"

    (
      cd "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}/bin"

      cp -v "busybox.exe" "sh.exe"
      cp -v "busybox.exe" "rm.exe"
      cp -v "busybox.exe" "echo.exe"
      cp -v "busybox.exe" "mkdir.exe"
    )
  )
}

function check_binaries()
{
  echo
  echo "Checking binaries for unwanted DLLs..."

  local binaries=$(find "${INSTALL_FOLDER_PATH}/${APP_LC_NAME}"/bin -name \*.exe)
  for bin in ${binaries}
  do
    check_binary "${bin}"
  done
}

function copy_distro_files()
{
  (
    xbb_activate

    rm -rf "${APP_PREFIX}/${DISTRO_INFO_NAME}"
    mkdir -pv "${APP_PREFIX}/${DISTRO_INFO_NAME}"

    copy_build_files

    echo
    echo "Copying distro files..."

    cd "${BUILD_GIT_PATH}"
    install -v -c -m 644 "scripts/${README_OUT_FILE_NAME}" \
      "${APP_PREFIX}/README.md"
  )
}
