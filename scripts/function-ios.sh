#!/bin/bash

source "${BASEDIR}/scripts/function-apple.sh"

prepare_inline_sed

enable_default_ios_architectures() {
  ENABLED_ARCHITECTURES[ARCH_ARMV7]=1
  ENABLED_ARCHITECTURES[ARCH_ARMV7S]=1
  ENABLED_ARCHITECTURES[ARCH_ARM64]=1
  ENABLED_ARCHITECTURES[ARCH_ARM64_MAC_CATALYST]=1
  ENABLED_ARCHITECTURES[ARCH_ARM64_SIMULATOR]=1
  ENABLED_ARCHITECTURES[ARCH_ARM64E]=1
  ENABLED_ARCHITECTURES[ARCH_I386]=1
  ENABLED_ARCHITECTURES[ARCH_X86_64]=1
  ENABLED_ARCHITECTURES[ARCH_X86_64_MAC_CATALYST]=1
}

display_help() {
  COMMAND=$(echo "$0" | sed -e 's/\.\///g')

  echo -e "\n'$COMMAND' builds FFmpegKit for iOS platform. By default nine architectures (armv7, armv7s, arm64, \
arm64-mac-catalyst, arm64-simulator, arm64e, i386, x86-64 and x86-64-mac-catalyst) are enabled without any external \
libraries. Options can be used to disable architectures and/or enable external libraries. Please note that GPL \
libraries (external libraries with GPL license) need --enable-gpl flag to be set explicitly. The minimum iOS version is set to 13. When compilation ends, \
libraries are created under the prebuilt folder.\n"
  echo -e "Usage: ./$COMMAND [OPTION]...\n"
  echo -e "Specify environment variables as VARIABLE=VALUE to override default build options.\n"

  display_help_options "  -x, --xcframework\t\tbuild xcframework bundles instead of framework bundles" "  -l, --lts			build lts packages to support sdk 13+ devices" "      --target=ios sdk version\t\t\toverride minimum deployment target [13]" "      --mac-catalyst-target=ios sdk version\toverride minimum deployment target for mac catalyst [14.0]"
  display_help_licensing

  echo -e "Architectures:"
  echo -e "  --disable-armv7\t\tdo not build armv7 architecture [yes]"
  echo -e "  --disable-armv7s\t\tdo not build armv7s architecture [yes]"
  echo -e "  --disable-arm64\t\tdo not build arm64 architecture [yes]"
  echo -e "  --disable-arm64-mac-catalyst\tdo not build arm64-mac-catalyst architecture [yes]"
  echo -e "  --disable-arm64-simulator\tdo not build arm64-simulator architecture [yes]"
  echo -e "  --disable-arm64e\t\tdo not build arm64e architecture [yes]"
  echo -e "  --disable-i386\t\tdo not build i386 architecture [yes]"
  echo -e "  --disable-x86-64\t\tdo not build x86-64 architecture [yes]"
  echo -e "  --disable-x86-64-mac-catalyst\tdo not build x86-64-mac-catalyst architecture [yes]\n"

  echo -e "Libraries:"

  echo -e "  --full\t\t\tenables all non-GPL external libraries"
  echo -e "  --enable-ios-audiotoolbox\tbuild with built-in Apple AudioToolbox support [no]"
  echo -e "  --enable-ios-avfoundation\tbuild with built-in Apple AVFoundation support [no]"
  echo -e "  --enable-ios-bzip2\t\tbuild with built-in bzip2 support [no]"
  echo -e "  --enable-ios-videotoolbox\tbuild with built-in Apple VideoToolbox support [no]"
  echo -e "  --enable-ios-zlib\t\tbuild with built-in zlib [no]"
  echo -e "  --enable-ios-libiconv\t\tbuild with built-in libiconv [no]"

  display_help_common_libraries
  display_help_gpl_libraries
  display_help_custom_libraries
  if [[ -n ${FFMPEG_KIT_XCF_BUILD} ]]; then
    display_help_advanced_options "  --no-framework\t\tdo not build xcframework bundles [no]"  "  --no-bitcode\t\t\tdo not enable bitcode in bundles [no]"
  else
    display_help_advanced_options "  --no-framework\t\tdo not build framework bundles [no]"  "  --no-bitcode\t\t\tdo not enable bitcode in bundles [no]"
  fi
}

enable_main_build() {
  if [[ $(compare_versions "$DETECTED_IOS_SDK_VERSION" "13") -le 0 ]]; then
    export IOS_MIN_VERSION=$DETECTED_IOS_SDK_VERSION
  else
    export IOS_MIN_VERSION=13
  fi

  if [[ $(compare_versions "$DETECTED_IOS_SDK_VERSION" "14.0") -le 0 ]]; then
    export MAC_CATALYST_MIN_VERSION=$DETECTED_IOS_SDK_VERSION
  else
    export MAC_CATALYST_MIN_VERSION=14.0
  fi
}

enable_lts_build() {
  export FFMPEG_KIT_LTS_BUILD="1"

  if [[ $(compare_versions "$DETECTED_IOS_SDK_VERSION" "13") -le 0 ]]; then
    export IOS_MIN_VERSION=$DETECTED_IOS_SDK_VERSION
  else

    # Updated minimum iOS version to 13
    export IOS_MIN_VERSION=13
  fi

  if [[ $(compare_versions "$DETECTED_IOS_SDK_VERSION" "13.0") -le 0 ]]; then
    export MAC_CATALYST_MIN_VERSION=$DETECTED_IOS_SDK_VERSION
  else

    # MAC CATALYST IS INTRODUCED IN 13.0
    export MAC_CATALYST_MIN_VERSION=13.0
  fi
}

get_common_includes() {
  echo "-I${SDK_PATH}/usr/include"
}

get_common_cflags() {
  if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
    local LTS_BUILD_FLAG="-DFFMPEG_KIT_LTS "
  fi

  local BUILD_DATE="-DFFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d 2>>"${BASEDIR}"/build.log)"
  if [ -z $NO_BITCODE ]; then
    local BITCODE_FLAGS="-fembed-bitcode"
  fi

  case ${ARCH} in
  i386 | x86-64 | arm64-simulator)
    echo "-fstrict-aliasing -DIOS ${LTS_BUILD_FLAG}${BUILD_DATE} -Wno-incompatible-function-pointer-types -isysroot ${SDK_PATH}"
    ;;
  *-mac-catalyst)
    echo "-fstrict-aliasing ${BITCODE_FLAGS} -DMACOSX ${LTS_BUILD_FLAG}${BUILD_DATE} -Wno-incompatible-function-pointer-types -isysroot ${SDK_PATH}"
    ;;
  *)
    echo "-fstrict-aliasing ${BITCODE_FLAGS} -DIOS ${LTS_BUILD_FLAG}${BUILD_DATE} -Wno-incompatible-function-pointer-types -isysroot ${SDK_PATH}"
    ;;
  esac
}

get_arch_specific_cflags() {
  case ${ARCH} in
  armv7)
    echo "-arch armv7 -target $(get_target) -march=armv7 -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=softfp -DFFMPEG_KIT_ARMV7"
    ;;
  armv7s)
    echo "-arch armv7s -target $(get_target) -march=armv7s -mcpu=generic -mfpu=neon -mfloat-abi=softfp -DFFMPEG_KIT_ARMV7S"
    ;;
  arm64)
    echo "-arch arm64 -target $(get_target) -march=armv8-a+crc+crypto -mcpu=generic -DFFMPEG_KIT_ARM64"
    ;;
  arm64-mac-catalyst)
    echo "-arch arm64 -target $(get_target) -march=armv8-a+crc+crypto -mcpu=generic -DFFMPEG_KIT_ARM64_MAC_CATALYST -isysroot ${SDK_PATH} -isystem ${SDK_PATH}/System/iOSSupport/usr/include -iframework ${SDK_PATH}/System/iOSSupport/System/Library/Frameworks"
    ;;
  arm64-simulator)
    echo "-arch arm64 -target $(get_target) -march=armv8-a+crc+crypto -mcpu=generic -DFFMPEG_KIT_ARM64_SIMULATOR"
    ;;
  arm64e)
    echo "-arch arm64e -target $(get_target) -march=armv8.3-a+crc+crypto -mcpu=generic -DFFMPEG_KIT_ARM64E"
    ;;
  i386)
    echo "-arch i386 -target $(get_target) -march=i386 -mtune=i386 -mssse3 -mfpmath=sse -m32 -DFFMPEG_KIT_I386"
    ;;
  x86-64)
    echo "-arch x86_64 -target $(get_target) -march=x86-64 -msse4.2 -mpopcnt -m64 -DFFMPEG_KIT_X86_64"
    ;;
  x86-64-mac-catalyst)
    echo "-arch x86_64 -target $(get_target) -march=x86-64 -msse4.2 -mpopcnt -m64 -DFFMPEG_KIT_X86_64_MAC_CATALYST -isysroot ${SDK_PATH} -isystem ${SDK_PATH}/System/iOSSupport/usr/include -iframework ${SDK_PATH}/System/iOSSupport/System/Library/Frameworks"
    ;;
  esac
}

get_size_optimization_cflags() {
  local ARCH_OPTIMIZATION=""
  case ${ARCH} in
  armv7 | armv7s | arm64 | arm64e | *-mac-catalyst)
    ARCH_OPTIMIZATION="-Oz -Wno-ignored-optimization-argument"
    ;;
  i386 | x86-64 | arm64-simulator)
    ARCH_OPTIMIZATION="-O2 -Wno-ignored-optimization-argument"
    ;;
  esac

  echo "${ARCH_OPTIMIZATION}"
}

get_size_optimization_asm_cflags() {
  local ARCH_OPTIMIZATION=""
  case $1 in
  jpeg | ffmpeg)
    case ${ARCH} in
    armv7 | armv7s | arm64 | arm64e | *-mac-catalyst)
      ARCH_OPTIMIZATION="-Oz"
      ;;
    i386 | x86-64 | arm64-simulator)
      ARCH_OPTIMIZATION="-O2"
      ;;
    esac
    ;;
  *)
    ARCH_OPTIMIZATION=$(get_size_optimization_cflags "$1")
    ;;
  esac

  echo "${ARCH_OPTIMIZATION}"
}

get_app_specific_cflags() {
  local APP_FLAGS=""
  case $1 in
  fontconfig)
    case ${ARCH} in
    armv7 | armv7s | arm64 | arm64e)
      APP_FLAGS="-std=c99 -Wno-unused-function -D__IPHONE_OS_MIN_REQUIRED -D__IPHONE_VERSION_MIN_REQUIRED=30000"
      ;;
    *)
      APP_FLAGS="-std=c99 -Wno-unused-function"
      ;;
    esac
    ;;
  ffmpeg)
    APP_FLAGS="-Wno-unused-function -Wno-deprecated-declarations"
    ;;
  ffmpeg-kit)
    APP_FLAGS="-std=c99 -Wno-unused-function -Wall -Wno-deprecated-declarations -Wno-pointer-sign -Wno-switch -Wno-unused-result -Wno-unused-variable -DPIC -fobjc-arc"
    ;;
  gnutls)
    APP_FLAGS="-std=c99 -Wno-unused-function -D_GL_USE_STDLIB_ALLOC=1"
    ;;
  jpeg)
    APP_FLAGS="-Wno-nullability-completeness"
    ;;
  kvazaar)
    APP_FLAGS="-std=gnu99 -Wno-unused-function"
    ;;
  leptonica)
    APP_FLAGS="-std=c99 -Wno-unused-function -DOS_IOS"
    ;;
  libwebp | xvidcore)
    APP_FLAGS="-fno-common -DPIC"
    ;;
  openh264 | openssl | x265)
    APP_FLAGS="-Wno-unused-function"
    ;;
  sdl)
    APP_FLAGS="-DPIC -Wno-declaration-after-statement -Wno-unused-function -D__IPHONEOS__"
    ;;
  shine)
    APP_FLAGS="-Wno-unused-function"
    ;;
  soxr | snappy)
    APP_FLAGS="-std=gnu99 -Wno-unused-function -DPIC"
    ;;
  *)
    APP_FLAGS="-std=c99 -Wno-unused-function"
    ;;
  esac

  echo "${APP_FLAGS}"
}

get_cflags() {
  local ARCH_FLAGS=$(get_arch_specific_cflags)
  local APP_FLAGS=$(get_app_specific_cflags "$1")
  local COMMON_FLAGS=$(get_common_cflags)
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS=$(get_size_optimization_cflags "$1")
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local MIN_VERSION_FLAGS=$(get_min_version_cflags "$1")
  local COMMON_INCLUDES=$(get_common_includes)

  echo "${ARCH_FLAGS} ${APP_FLAGS} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS} ${MIN_VERSION_FLAGS} ${COMMON_INCLUDES}"
}

get_asmflags() {
  local ARCH_FLAGS=$(get_arch_specific_cflags)
  local APP_FLAGS=$(get_app_specific_cflags "$1")
  local COMMON_FLAGS=$(get_common_cflags)
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS=$(get_size_optimization_asm_cflags "$1")
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local MIN_VERSION_FLAGS=$(get_min_version_cflags "$1")
  local COMMON_INCLUDES=$(get_common_includes)

  echo "${ARCH_FLAGS} ${APP_FLAGS} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS} ${MIN_VERSION_FLAGS} ${COMMON_INCLUDES}"
}

get_cxxflags() {
  local COMMON_CFLAGS="$(get_common_cflags "$1") $(get_common_includes "$1") $(get_arch_specific_cflags) $(get_min_version_cflags "$1")"
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS="-Oz"
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi

  local BITCODE_FLAGS=""
  case ${ARCH} in
  armv7 | armv7s | arm64 | arm64e | *-mac-catalyst)
    if [ -z $NO_BITCODE ]; then
      local BITCODE_FLAGS="-fembed-bitcode"
    fi
    ;;
  esac

  case $1 in
  x265)
    echo "-std=c++11 -fno-exceptions ${BITCODE_FLAGS} ${COMMON_CFLAGS}"
    ;;
  gnutls)
    echo "-std=c++11 -fno-rtti ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  libaom)
    echo "-std=c++11 -fno-exceptions ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  libilbc)
    echo "-std=c++14 -fno-exceptions -fno-rtti ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  libwebp | xvidcore)
    echo "-std=c++11 -fno-exceptions -fno-rtti ${BITCODE_FLAGS} -fno-common -DPIC ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  opencore-amr)
    echo "-fno-rtti ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  rubberband)
    echo "-fno-rtti -Wno-c++11-narrowing ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  srt | tesseract | zimg)
    echo "-std=c++11 ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  *)
    echo "-std=c++11 -fno-exceptions -fno-rtti ${BITCODE_FLAGS} ${COMMON_CFLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  esac
}

get_common_linked_libraries() {
  echo "-L${SDK_PATH}/usr/lib -lc++"
}

get_common_ldflags() {
  echo "-isysroot ${SDK_PATH} $(get_min_version_cflags)"
}

get_size_optimization_ldflags() {
  case ${ARCH} in
  armv7 | armv7s | arm64 | arm64e | *-mac-catalyst)
    case $1 in
    ffmpeg | ffmpeg-kit)
      echo "-Oz -dead_strip"
      ;;
    *)
      echo "-Oz -dead_strip"
      ;;
    esac
    ;;
  *)
    case $1 in
    ffmpeg)
      echo "-O2"
      ;;
    *)
      echo "-O2"
      ;;
    esac
    ;;
  esac
}

get_arch_specific_ldflags() {
  case ${ARCH} in
  armv7)
    echo "-arch armv7 -march=armv7 -mfpu=neon -mfloat-abi=softfp -target $(get_target)"
    ;;
  armv7s)
    echo "-arch armv7s -march=armv7s -mfpu=neon -mfloat-abi=softfp -target $(get_target)"
    ;;
  arm64)
    echo "-arch arm64 -march=armv8-a+crc+crypto -target $(get_target)"
    ;;
  arm64-mac-catalyst)
    echo "-arch arm64 -march=armv8-a+crc+crypto -target $(get_target) -isysroot ${SDK_PATH} -L${SDK_PATH}/System/iOSSupport/usr/lib -iframework ${SDK_PATH}/System/iOSSupport/System/Library/Frameworks"
    ;;
  arm64-simulator)
    echo "-arch arm64 -march=armv8-a+crc+crypto -target $(get_target)"
    ;;
  arm64e)
    echo "-arch arm64e -march=armv8.3-a+crc+crypto -target $(get_target)"
    ;;
  i386)
    echo "-arch i386 -march=i386 -target $(get_target)"
    ;;
  x86-64)
    echo "-arch x86_64 -march=x86-64 -target $(get_target)"
    ;;
  x86-64-mac-catalyst)
    echo "-arch x86_64 -march=x86-64 -target $(get_target) -isysroot ${SDK_PATH} -L${SDK_PATH}/System/iOSSupport/usr/lib -iframework ${SDK_PATH}/System/iOSSupport/System/Library/Frameworks"
    ;;
  esac
}

get_ldflags() {
  local ARCH_FLAGS=$(get_arch_specific_ldflags)
  local LINKED_LIBRARIES=$(get_common_linked_libraries)
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS="$(get_size_optimization_ldflags $1)"
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local COMMON_FLAGS=$(get_common_ldflags)
  if [ -z $NO_BITCODE ]; then
    local BITCODE_FLAGS="-fembed-bitcode -Wc,-fembed-bitcode"
  fi

  case $1 in
  ffmpeg-kit)
    case ${ARCH} in
    armv7 | armv7s | arm64 | arm64e | *-mac-catalyst)
      echo "${ARCH_FLAGS} ${LINKED_LIBRARIES} ${COMMON_FLAGS} ${BITCODE_FLAGS} ${OPTIMIZATION_FLAGS}"
      ;;
    *)
      echo "${ARCH_FLAGS} ${LINKED_LIBRARIES} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS}"
      ;;
    esac
    ;;
  *)
    # NOTE THAT ffmpeg ALSO NEEDS BITCODE, IT IS ENABLED IN ffmpeg.sh
    echo "${ARCH_FLAGS} ${LINKED_LIBRARIES} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS}"
    ;;
  esac
}

set_toolchain_paths() {
  if [ ! -f "${FFMPEG_KIT_TMPDIR}/gas-preprocessor.pl" ]; then
    DOWNLOAD_RESULT=$(download "https://github.com/arthenica/gas-preprocessor/raw/v20210917/gas-preprocessor.pl" "gas-preprocessor.pl" "exit")
    if [[ ${DOWNLOAD_RESULT} -ne 0 ]]; then
      exit 1
    fi
    (chmod +x "${FFMPEG_KIT_TMPDIR}"/gas-preprocessor.pl 1>>"${BASEDIR}"/build.log 2>&1) || return 1

    # patch gas-preprocessor.pl against the following warning
    # Unescaped left brace in regex is deprecated here (and will be fatal in Perl 5.32), passed through in regex; marked by <-- HERE in m/(?:ld|st)\d\s+({ <-- HERE \s*v(\d+)\.(\d[bhsdBHSD])\s*-\s*v(\d+)\.(\d[bhsdBHSD])\s*})/ at /Users/taner/Projects/ffmpeg-kit/.tmp/gas-preprocessor.pl line 1065.
    sed -i .tmp "s/s\+({/s\+(\\\\{/g;s/s\*})/s\*\\\\})/g" "${FFMPEG_KIT_TMPDIR}"/gas-preprocessor.pl
  fi

  LOCAL_GAS_PREPROCESSOR="${FFMPEG_KIT_TMPDIR}/gas-preprocessor.pl"
  if [ "$1" == "x264" ]; then
    LOCAL_GAS_PREPROCESSOR="${BASEDIR}/src/x264/tools/gas-preprocessor.pl"
  fi

  export AR="$(xcrun --sdk "$(get_sdk_name)" -f ar 2>>"${BASEDIR}"/build.log)"
  export CC="clang"
  export OBJC="$(xcrun --sdk "$(get_sdk_name)" -f clang 2>>"${BASEDIR}"/build.log)"
  export CXX="clang++"

  LOCAL_ASMFLAGS="$(get_asmflags $1)"
  case ${ARCH} in
  armv7*)
    if [ "$1" == "x265" ] || [ "$1" == "libilbc" ]; then
      export AS="${LOCAL_GAS_PREPROCESSOR}"
      export AS_ARGUMENTS="-arch arm"
      export ASM_FLAGS="${LOCAL_ASMFLAGS}"
    else
      export AS="${LOCAL_GAS_PREPROCESSOR} -arch arm -- ${CC} ${LOCAL_ASMFLAGS}"
    fi
    ;;
  arm64*)
    if [ "$1" == "x265" ] || [ "$1" == "libilbc" ]; then
      export AS="${LOCAL_GAS_PREPROCESSOR}"
      export AS_ARGUMENTS="-arch aarch64"
      export ASM_FLAGS="${LOCAL_ASMFLAGS}"
    else
      export AS="${LOCAL_GAS_PREPROCESSOR} -arch aarch64 -- ${CC} ${LOCAL_ASMFLAGS}"
    fi
    ;;
  *)
    export AS="${CC} ${LOCAL_ASMFLAGS}"
    ;;
  esac

  export LD="$(xcrun --sdk "$(get_sdk_name)" -f ld 2>>"${BASEDIR}"/build.log)"
  export RANLIB="$(xcrun --sdk "$(get_sdk_name)" -f ranlib 2>>"${BASEDIR}"/build.log)"
  export STRIP="$(xcrun --sdk "$(get_sdk_name)" -f strip 2>>"${BASEDIR}"/build.log)"
  export NM="$(xcrun --sdk "$(get_sdk_name)" -f nm 2>>"${BASEDIR}"/build.log)"

  export INSTALL_PKG_CONFIG_DIR="${BASEDIR}/prebuilt/$(get_build_directory)/pkgconfig"
  export ZLIB_PACKAGE_CONFIG_PATH="${INSTALL_PKG_CONFIG_DIR}/zlib.pc"
  export BZIP2_PACKAGE_CONFIG_PATH="${INSTALL_PKG_CONFIG_DIR}/bzip2.pc"
  export LIB_ICONV_PACKAGE_CONFIG_PATH="${INSTALL_PKG_CONFIG_DIR}/libiconv.pc"
  export LIB_UUID_PACKAGE_CONFIG_PATH="${INSTALL_PKG_CONFIG_DIR}/uuid.pc"

  if [ ! -d "${INSTALL_PKG_CONFIG_DIR}" ]; then
    mkdir -p "${INSTALL_PKG_CONFIG_DIR}"
  fi

  if [ ! -f "${ZLIB_PACKAGE_CONFIG_PATH}" ]; then
    create_zlib_system_package_config
  fi

  if [ ! -f "${LIB_ICONV_PACKAGE_CONFIG_PATH}" ]; then
    create_libiconv_system_package_config
  fi

  if [ ! -f "${BZIP2_PACKAGE_CONFIG_PATH}" ]; then
    create_bzip2_system_package_config
  fi

  if [ ! -f "${LIB_UUID_PACKAGE_CONFIG_PATH}" ]; then
    create_libuuid_system_package_config
  fi
}

initialize_prebuilt_ios_folders() {
  if [[ -n ${FFMPEG_KIT_XCF_BUILD} ]]; then

    echo -e "DEBUG: Initializing universal directories and frameworks for xcf builds\n" 1>>"${BASEDIR}"/build.log 2>&1

    if [[ $(is_apple_architecture_variant_supported "${ARCH_VAR_IPHONEOS}") -eq 1 ]]; then
      initialize_folder "${BASEDIR}/.tmp/$(get_universal_library_directory "${ARCH_VAR_IPHONEOS}")"
      initialize_folder "${BASEDIR}/prebuilt/$(get_framework_directory "${ARCH_VAR_IPHONEOS}")"
    fi
    if [[ $(is_apple_architecture_variant_supported "${ARCH_VAR_IPHONESIMULATOR}") -eq 1 ]]; then
      initialize_folder "${BASEDIR}/.tmp/$(get_universal_library_directory "${ARCH_VAR_IPHONESIMULATOR}")"
      initialize_folder "${BASEDIR}/prebuilt/$(get_framework_directory "${ARCH_VAR_IPHONESIMULATOR}")"
    fi
    if [[ $(is_apple_architecture_variant_supported "${ARCH_VAR_MAC_CATALYST}") -eq 1 ]]; then
      initialize_folder "${BASEDIR}/.tmp/$(get_universal_library_directory "${ARCH_VAR_MAC_CATALYST}")"
      initialize_folder "${BASEDIR}/prebuilt/$(get_framework_directory "${ARCH_VAR_MAC_CATALYST}")"
    fi

    echo -e "DEBUG: Initializing xcframework directory at ${BASEDIR}/prebuilt/$(get_xcframework_directory)\n" 1>>"${BASEDIR}"/build.log 2>&1

    # XCF BUILDS GENERATE XCFFRAMEWORKS
    initialize_folder "${BASEDIR}/prebuilt/$(get_xcframework_directory)"
  else

    echo -e "DEBUG: Initializing default universal directory at ${BASEDIR}/.tmp/$(get_universal_library_directory "${ARCH_VAR_IOS}")\n" 1>>"${BASEDIR}"/build.log 2>&1

    # DEFAULT BUILDS GENERATE UNIVERSAL LIBRARIES AND FRAMEWORKS
    initialize_folder "${BASEDIR}/.tmp/$(get_universal_library_directory "${ARCH_VAR_IOS}")"

    echo -e "DEBUG: Initializing framework directory at ${BASEDIR}/prebuilt/$(get_framework_directory "${ARCH_VAR_IOS}")\n" 1>>"${BASEDIR}"/build.log 2>&1

    initialize_folder "${BASEDIR}/prebuilt/$(get_framework_directory "${ARCH_VAR_IOS}")"
  fi
}

#
# DEPENDS TARGET_ARCH_LIST VARIABLE
#
create_universal_libraries_for_ios_default_frameworks() {
  local ROOT_UNIVERSAL_DIRECTORY_PATH="${BASEDIR}/.tmp/$(get_universal_library_directory 1)"

  echo -e "INFO: Building universal libraries in ${ROOT_UNIVERSAL_DIRECTORY_PATH} for default frameworks using ${TARGET_ARCH_LIST[@]}\n" 1>>"${BASEDIR}"/build.log 2>&1

  create_ffmpeg_universal_library "${ARCH_VAR_IOS}"

  create_ffmpeg_kit_universal_library "${ARCH_VAR_IOS}"

  echo -e "INFO: Universal libraries for default frameworks built successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
}

create_ios_default_frameworks() {
  echo -e "INFO: Building default frameworks\n" 1>>"${BASEDIR}"/build.log 2>&1

  create_ffmpeg_framework "${ARCH_VAR_IOS}"

  create_ffmpeg_kit_framework "${ARCH_VAR_IOS}"

  echo -e "INFO: Default frameworks built successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
}

create_universal_libraries_for_ios_xcframeworks() {
  echo -e "INFO: Building universal libraries for xcframeworks using ${TARGET_ARCH_LIST[@]}\n" 1>>"${BASEDIR}"/build.log 2>&1

  create_ffmpeg_universal_library "${ARCH_VAR_IPHONEOS}"
  create_ffmpeg_universal_library "${ARCH_VAR_IPHONESIMULATOR}"
  create_ffmpeg_universal_library "${ARCH_VAR_MAC_CATALYST}"

  create_ffmpeg_kit_universal_library "${ARCH_VAR_IPHONEOS}"
  create_ffmpeg_kit_universal_library "${ARCH_VAR_IPHONESIMULATOR}"
  create_ffmpeg_kit_universal_library "${ARCH_VAR_MAC_CATALYST}"

  echo -e "INFO: Universal libraries for xcframeworks built successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
}

create_frameworks_for_ios_xcframeworks() {
  echo -e "INFO: Building frameworks for xcframeworks\n" 1>>"${BASEDIR}"/build.log 2>&1

  create_ffmpeg_framework "${ARCH_VAR_IPHONEOS}"
  create_ffmpeg_framework "${ARCH_VAR_IPHONESIMULATOR}"
  create_ffmpeg_framework "${ARCH_VAR_MAC_CATALYST}"

  create_ffmpeg_kit_framework "${ARCH_VAR_IPHONEOS}"
  create_ffmpeg_kit_framework "${ARCH_VAR_IPHONESIMULATOR}"
  create_ffmpeg_kit_framework "${ARCH_VAR_MAC_CATALYST}"

  echo -e "INFO: Frameworks for xcframeworks built successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
}

create_ios_xcframeworks() {
  export ARCHITECTURE_VARIANT_ARRAY=("${ARCH_VAR_IPHONEOS}" "${ARCH_VAR_IPHONESIMULATOR}" "${ARCH_VAR_MAC_CATALYST}")
  echo -e "INFO: Building xcframeworks\n" 1>>"${BASEDIR}"/build.log 2>&1

  create_ffmpeg_xcframework

  create_ffmpeg_kit_xcframework

  echo -e "INFO: xcframeworks built successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
}
