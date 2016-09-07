CMAKE_MINIMUM_REQUIRED(VERSION 3.0)
PROJECT(x264 C ASM-NASM)

if(NOT "${CMAKE_SYSTEM_PROCESSOR}" MATCHES ".86" OR NOT "${CMAKE_SYSTEM_PROCESSOR}" MATCHES "AMD64")
  message(FATAL_ERROR "${CMAKE_SYSTEM_PROCESSOR} currently not supported")
endif()

################################ BUILD OPTIONS ################################
option(WITH_SHARED "build a shared library" ON)
option(WITH_STATIC "build a static library" OFF)
option(WITH_CLI    "build command line app" ON)
option(WITH_OPENCL "build with opencl features on (currently unsupported in cmake)" OFF)
option(WITH_GPL_FEATURES "build with gpl-only features on" ON)

if(WIN32)
  option(WITH_THREADS "build with POSIX multithreading on" OFF)
  option(WITH_WIN32THREADS "build with windows32 multithreading on" ON)
else(WIN32)
  option(WITH_THREADS "build with POSIX multithreading on" ON)
  option(WITH_WIN32THREADS "build with windows32 multithreading on" OFF)
endif()

option(WITH_INTERLACED "build with interlaced encoding support" ON)
option(WITH_ASM "platform-specific assembly optimizations" ON)
option(WITH_LTO "link-time optimization (only gcc/UNIX supported)" OFF)
option(WITH_PROFILING "enabled profiling (only gcc/UNIX supported)" OFF)
option(WITH_STRIP "strip binaires (only gcc/UNIX supported)" ON)
option(WITH_PIC    "build a binaries with position independent code" OFF)
option(WITH_AVS "build with avisynth support (currently unsupported in cmake)" ON)
option(WITH_SWSCALE "build with libswscale support (currently unsupported in cmake)" ON)
option(WITH_LAVF "build with lavformat support (currently unsupported in cmake)" OFF)
option(WITH_FFMS "build with ffmpeg source support (currently unsupported in cmake)" OFF)
option(WITH_GPAC "build with gpac support (currently unsupported in cmake)" ON)
option(WITH_LSMASH "build with lsmash support (currently unsupported in cmake)" ON)
option(WITH_SYS_X264 "build with system libx264 support (currently unsupported in cmake)" OFF)

################################ GLOBAL DEFINES ################################
#set output bit depth (8-10) [8]
if(NOT DEFINED X264_BIT_DEPTH)
  set(X264_BIT_DEPTH 8)
endif()

#output chroma format (420, 422, 444, all) [all]
if(NOT DEFINED X264_CHROMA_FORMAT)
  set(X264_CHROMA_FORMAT all)
endif()

include(CheckCCompilerFlag)
check_c_compiler_flag(-Wno-maybe-uninitialized HAS_NOMAYBE_UNINITIALISED)
check_c_compiler_flag(-Wshadow HAS_SHADOW)
check_c_compiler_flag(-Wall HAS_ALL)
check_c_compiler_flag(-ffast-math HAS_FAST_MATH)
check_c_compiler_flag(-O3 HAS_O3)
check_c_compiler_flag(-g HAS_G)
check_c_compiler_flag(-m64 HAS_M64)
check_c_compiler_flag(-mpreferred-stack-boundary=5 HAS_PREF_STACK_BOUNDARY)
check_c_compiler_flag(-fomit-frame-pointer HAS_OMIT_FRAMEPOINTER)
check_c_compiler_flag(-fno-tree-vectorize HAS_NO_TREE_VECTORIZE)
check_c_compiler_flag(-std=gnu99 HAS_STD_GNU99)

set(EXTRA_CFLAGS "")
if(UNIX)
  if(HAS_NOMAYBE_UNINITIALISED)
    list(APPEND EXTRA_CFLAGS -Wno-maybe-uninitialized)
  endif()

  if(HAS_SHADOW)
    list(APPEND EXTRA_CFLAGS -Wshadow)
  endif()

  if(HAS_ALL)
    list(APPEND EXTRA_CFLAGS -Wall)
  endif()

  if(HAS_FAST_MATH)
    list(APPEND EXTRA_CFLAGS -ffast-math)
  endif()

  #TODO: maybe not needed as it could be controlled by cmake-variables
  if(HAS_M64)
    list(APPEND EXTRA_CFLAGS -m64)
  endif()

  if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
    if(HAS_O3)
      list(APPEND EXTRA_CFLAGS -O3)
    endif()
  else()
    if(HAS_G)
      list(APPEND EXTRA_CFLAGS -g)
    endif()
  endif()

  if(HAS_PREF_STACK_BOUNDARY)
    list(APPEND EXTRA_CFLAGS -mpreferred-stack-boundary=5)
  endif()

  if(HAS_OMIT_FRAMEPOINTER)
    list(APPEND EXTRA_CFLAGS -fomit-frame-pointer)
  endif()
endif(UNIX)

string(REPLACE ";" " " CMAKE_C_FLAGS ${EXTRA_CFLAGS})
if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
  set(CMAKE_C_FLAGS_RELEASE ${EXTRA_CFLAGS})
  set(CMAKE_C_FLAGS_RELWDBG ${EXTRA_CFLAGS})
endif()

if(${CMAKE_BUILD_TYPE} MATCHES "Debug")
  set(CMAKE_C_FLAGS_DEBUG ${EXTRA_CFLAGS})
endif()

get_filename_component(X264_SOURCE_ROOT ${PROJECT_SOURCE_DIR}/.. ABSOLUTE)
include_directories(${X264_SOURCE_ROOT})
add_subdirectory(${X264_SOURCE_ROOT})

################################ COLLECT C SOURCES ################################

set(X264_SRCS "common/mc.c;common/predict.c;common/pixel.c;common/macroblock.c;common/frame.c;common/dct.c;common/cpu.c;common/cabac.c;common/common.c;common/osdep.c;common/rectangle.c;common/set.c;common/quant.c;common/deblock.c;common/vlc.c;common/mvpred.c;common/bitstream.c;encoder/analyse.c;encoder/me.c;encoder/ratecontrol.c;encoder/set.c;encoder/macroblock.c;encoder/cabac.c;encoder/cavlc.c;encoder/encoder.c;encoder/lookahead.c")

set(X264_SRCCLI "x264.c;input/input.c;input/timecode.c;input/raw.c;input/y4m.c;output/raw.c;output/matroska.c;output/matroska_ebml.c;output/flv.c;output/flv_bytestream.c;filters/filters.c;filters/video/video.c;filters/video/source.c;filters/video/internal.c;filters/video/resize.c;filters/video/cache.c;filters/video/fix_vfr_pts.c;filters/video/select_every.c;filters/video/crop.c;filters/video/depth.c")


if(WITH_AVS)
  list(APPEND X264_SRCCLI input/avs.c)
endif()

if(WITH_FFMS)
  list(APPEND X264_SRCS input/ffms.c)
endif()

if(WITH_THREADS)
  list(APPEND X264_SRCCLI input/thread.c)
  list(APPEND X264_SRCS common/threadpool.c)
endif()

if(WITH_WIN32THREAD)
  list(APPEND X264_SRCS common/win32thread.c)
endif()

if(WITH_LAVF)
  list(APPEND X264_SRCCLI input/lavf.c)
endif()

if(WITH_FFMS)
  list(APPEND X264_SRCCLI input/ffms.c)
endif()

if(WITH_GPAC)
  list(APPEND X264_SRCCLI output/mp4.c)
endif()

if(WITH_LSMASH)
  list(APPEND X264_SRCCLI output/mp4_lsmash.c)
endif()

################################ PRODUCE C OBJECT FILES ################################
list(APPEND X264_SRCS common/x86/mc-c.c common/x86/predict-c.c)

add_library(x264-objects OBJECTS ${X264_SRCS})
add_library(x264-app OBJECTS ${X264_SRCCLI})

if( CMAKE_SIZEOF_VOID_P MATCHES 8 )
    # void ptr = 8 byte --> x86_64
    set(CPU_ARCH "x86_64")
    
else()
    # void ptr != 8 byte --> x86
    set(CPU_ARCH "x86")
endif()

################################ COLLECT ASM SOURCES ################################

list(APPEND X264_X86SRC0 const-a.asm cabac-a.asm dct-a.asm deblock-a.asm mc-a.asm mc-a2.asm pixel-a.asm predict-a.asm quant-a.asm cpu-a.asm dct-32.asm bitstream-a.asm )

if(NOT X264_HIGH_BIT_DEPTH)
  list(APPEND X264_X86SRC0 sad-a.asm)
else()
  list(APPEND X264_X86SRC0 sad16-a.asm)
endif()

foreach(_ASM IN LISTS X264_X86SRC0)
  list(APPEND X264_X86SRC common/x86/${_ASM})
endforeach()

if(${CPU_ARCH} STREQUAL "x86_64")
  string(REPLACE "-32" "-64" ASMSRC "${X264_X86SRC}")
  list(APPEND ASMSRC common/x86/trellis-64.asm)
else()
  list(APPEND ASMSRC ${X264_X86SRC} common/x86/pixel-32.asm)
endif()

if(NOT YASM_ROOT)
  if(DEFINED ENV{YASM_ROOT})
    set(YASM_ROOT ENV{YASM_ROOT})
  endif()
endif()

################################ COLLECT ASM APP ################################
find_program(YASM_APP NAMES yasm yasm${CMAKE_EXECUTABLE_SUFFIX} NAMES_PER_DIR HINTS ${YASM_ROOT} PATHS ${YASM_ROOT} PATH_SUFFIXES bin)
if(NOT ${YASM_APP})
  message(FATAL_ERROR "unable to locate yasm, exiting (hint cmake for the path containing yasm by defining YASM_ROOT)")
endif()
set(CMAKE_ASM_COMPILER ${YASM_APP})
################################ COLLECT ASM FLAGS ################################
set(ASM_FLAG_LIST -I${X264_SOURCE_ROOT} -I${X264_SOURCE_ROOT}/common/x86/ -Worphan-labels -DSTACK_ALIGNMENT=32)

if(${CPU_ARCH} STREQUAL "x86_64")
  list(APPEND ASM_FLAG_LIST -DARCH_X86_64=1)
endif()
 
if(WITH_PIC)
  list(APPEND ASM_FLAG_LIST -DPIC)
endif()

if(${X264_BIT_DEPTH} EQUALS 8)
  list(APPEND ASM_FLAG_LIST -DHIGH_BIT_DEPTH=0)
endif()

list(APPEND ASM_FLAG_LIST -DBIT_DEPTH=${X264_BIT_DEPTH})

string(REPLACE ";" " " CMAKE_ASM_FLAGS ${ASM_FLAG_LIST})

add_library(x264-asm OBJECTS ${ASMSRC})


if(${WITH_SHARED})
  add_library(x264-shared SHARED)
  target_link_library(x264-objects x264-asm)
  set_target_properties(x264-shared PROPERTIES OUTPUT_NAME ${CMAKE_SHARED_LIBRARY_PREFIX}x264${CMAKE_SHARED_LIBRARY_SUFFIX})
endif()
  
if(${WITH_STATIC})
  add_library(x264-static STATIC)
  target_link_library(x264-objects x264-asm)
  set_target_properties(x264-static PROPERTIES OUTPUT_NAME ${CMAKE_STATIC_LIBRARY_PREFIX}x264${CMAKE_STATIC_LIBRARY_SUFFIX})
endif()

if(${WITH_CLI})
  add_executable(x264 ${X264_SRCCLI})
  target_link_library(x264-objects x264-asm)
endif()
