CMAKE_MINIMUM_REQUIRED(VERSION 3.0)
PROJECT(x264 C)

if(NOT ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES ".86_64" OR "${CMAKE_SYSTEM_PROCESSOR}" MATCHES ".86$" OR "${CMAKE_SYSTEM_PROCESSOR}" MATCHES "AMD64"))
  message(FATAL_ERROR "${CMAKE_SYSTEM_PROCESSOR} currently not supported")
endif()

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif()

################################ BUILD OPTIONS ################################
option(WITH_SHARED "build a shared library" OFF)
option(WITH_STATIC "build a static library" ON)
option(WITH_CLI    "build command line app" OFF)
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
option(WITH_STRIP "strip binaires (only gcc/UNIX supported)" ON)
option(WITH_PIC    "build a binaries with position independent code" ON)

option(WITH_AVS "build with avisynth support (currently unsupported in cmake)" ON)
option(WITH_SWSCALE "build with libswscale support (currently unsupported in cmake)" ON)
option(WITH_LAVF "build with lavformat support (currently unsupported in cmake)" OFF)
option(WITH_FFMS "build with ffmpeg source support (currently unsupported in cmake)" OFF)
option(WITH_GPAC "build with gpac support (currently unsupported in cmake)" OFF)
option(WITH_LSMASH "build with lsmash support (currently unsupported in cmake)" OFF)
option(WITH_SYS_X264 "build with system libx264 support (currently unsupported in cmake)" OFF)
option(WITH_LTO "link-time optimization (only gcc/UNIX supported) (currently unsupported in cmake)" OFF)
option(WITH_PROFILING "enabled profiling (only gcc/UNIX supported) (currently unsupported in cmake)" OFF)

################################ GLOBAL DEFINES ################################
if(WITH_SHARED)
  set(WITH_PIC ON)
endif()

#set output bit depth (8-10) [8]
if(NOT DEFINED X264_BIT_DEPTH)
  set(X264_BIT_DEPTH 8)
endif()

#output chroma format (420, 422, 444, all) [all]
if(NOT DEFINED X264_CHROMA_FORMAT)
  set(X264_CHROMA_FORMAT all)
  set(X264_CHROMA_FLAG 0)
endif()

include(CheckCSourceCompiles)
include(CheckCSourceRuns)
include(CheckIncludeFile)
include(CheckCCompilerFlag)
include(CheckFunctionExists)
include(CheckSymbolExists)
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}")
include(list_utils)
check_c_compiler_flag(-Wno-maybe-uninitialized HAS_NOMAYBE_UNINITIALISED)
check_c_compiler_flag(-Wshadow HAS_SHADOW)
check_c_compiler_flag(-Wall HAS_ALL)
check_c_compiler_flag(-ffast-math HAS_FAST_MATH)
check_c_compiler_flag(-O3 HAS_O3)
check_c_compiler_flag(-g HAS_G)
check_c_compiler_flag(-m64 HAS_M64)
check_c_compiler_flag(-mpreferred-stack-boundary=5 HAS_PREF_STACK_BOUNDARY5)
check_c_compiler_flag(-mpreferred-stack-boundary=4 HAS_PREF_STACK_BOUNDARY4)
check_c_compiler_flag(-fomit-frame-pointer HAS_OMIT_FRAMEPOINTER)
check_c_compiler_flag(-fno-tree-vectorize HAS_NO_TREE_VECTORIZE)
check_c_compiler_flag(-std=gnu99 HAS_STD_GNU99)
check_c_compiler_flag(-std=c99 HAS_STD_C99)
check_c_compiler_flag(-shared HAS_SHARED)
check_c_compiler_flag(-Wl,-Bsymbolic HAS_LINK_SYMBOLIC)
check_c_compiler_flag(-fPIC HAS_PIC)

check_function_exists(getopt_long HAS_GETOPT_LONG)

check_include_file(math.h HAS_MATH_H)
check_include_file(dlfcn.h HAS_DLFCN_H)
check_include_file(malloc.h HAS_MALLOC_H)
check_include_file(sched.h HAS_SCHED_H)
check_include_file(sys/mman.h HAS_MMAN_H)
check_include_file(unistd.h HAS_UNISTD_H)
check_include_file(string.h HAS_STRING_H)
check_include_file(strings.h HAS_STRINGS_H)
check_include_file(getopt.h HAS_GETOPT_H)

#set(HAS_LOG2F 0)
if(HAS_MATH_H)
  check_C_source_compiles("#include <math.h>;\nint main(){return log2f(2);}" HAS_LOG2F)
endif()

if(HAS_STD_GNU99)
  set(CMAKE_REQUIRED_FLAGS "-std=gnu99 -D_GNU_SOURCE")
  check_C_source_compiles("int main(){for( int i = 0; i < 9; i++ );;return 0;}" COMPILES_GNU99)
endif()

if(HAS_STD_C99)
  set(CMAKE_REQUIRED_FLAGS "-std=c99 -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE")
  check_C_source_compiles("int main(){for( int i = 0; i < 9; i++ );;return 0;}" COMPILES_C99)
endif()


  

if(HAS_MMAN_H)
  check_symbol_exists(MAP_PRIVATE sys/mman.h HAS_MMAP)
  check_symbol_exists(MADV_HUGEPAGE sys/mman.h HAS_THP)
  else()
    set(HAS_THP 0)
    set(HAS_MMAP "0")
endif()

if(HAS_SCHED_H)
  set(CMAKE_REQUIRED_FLAGS -D_GNU_SOURCE -Werror)
  check_C_source_compiles("#include <sched.h>\nvoid main(){cpu_set_t p_aff; return CPU_COUNT(&p_aff);}" HAS_CPU_COUNT)
else()
  set(HAS_CPU_COUNT 0)
endif()

check_C_source_compiles("void main(){__asm__(\"pabsw %xmm0, %xmm0\");}" HAS_X86_INLINE_ASM)
if(HAS_X86_INLINE_ASM)
  check_C_source_compiles("void main(){__asm__(\"pabsw %xmm0, %xmm0\");}" HAS_MMX)
else()
  set(HAS_X86_INLINE_ASM 0)
  set(HAS_MMX 0)
endif()

check_C_source_compiles("#include <stdint.h>\nvoid main(){uint32_t test_vec __attribute__ ((vector_size (16))) = {0,1,2,3};}" HAS_VECTOREXT)
if(NOT HAS_VECTOREXT)
set(HAS_VECTOREXT 0)
endif()

check_symbol_exists(fseeko stdio.h HAS_FSEEKO)
check_symbol_exists(fseeko64 stdio.h HAS_FSEEKO64)
check_symbol_exists(_fseeki64 stdio.h HAS_FSEEKI64)

if(HAS_FSEEKO)
  set(X264_FSEEK fseeko)
  set(X264_FTELL ftello)
elseif(HAS_FSEEKO64)
  set(X264_FSEEK fseeko)
  set(X264_FTELL ftello)
elseif(HAS_FSEEKI64)
  set(X264_FSEEK fseeko)
  set(X264_FTELL ftello)
endif()

if(WITH_GPL_FEATURES)
  set(X264_USE_GPL 1)
else()
  set(X264_USE_GPL 0)
endif()

if(WITH_INTERLACED)
  set(X264_USE_INTERLACED 1)
else()
  set(X264_USE_INTERLACED 0)
endif()

set(X264_STACK_ALIGNMENT 4)

if(HAS_PREF_STACK_BOUNDARY5)
  set(CMAKE_REQUIRED_FLAGS -mpreferred-stack-boundary=5)
  check_C_source_compiles("void main(){}" BUILDSWITH_PREF_STACK_BOUNDARY5)
  if(BUILDSWITH_PREF_STACK_BOUNDARY5)
    set(X264_STACK_ALIGNMENT 32)
  endif()
endif()

if(${X264_STACK_ALIGNMENT} LESS 16 AND HAS_PREF_STACK_BOUNDARY4)
  set(CMAKE_REQUIRED_FLAGS -mpreferred-stack-boundary=4)
  check_C_source_compiles("void main(){}" BUILDSWITH_PREF_STACK_BOUNDARY4)
  if(BUILDSWITH_PREF_STACK_BOUNDARY4)
    set(X264_STACK_ALIGNMENT 16)
  endif()
endif()


if( CMAKE_SIZEOF_VOID_P MATCHES 8 )
    set(CPU_ARCH "x86_64")
else()
    set(CPU_ARCH "x86")
endif()

if(("${CMAKE_SYSTEM_PROCESSOR}" MATCHES ".86_64" OR "${CMAKE_SYSTEM_PROCESSOR}" MATCHES "AMD64") AND ("${CPU_ARCH}" MATCHES ".*64$"))
  set(ARCH_X86_64 1)
else()
  set(ARCH_X86_64 0)
endif()

message(STATUS "detected ARCH_X86_64=${ARCH_X86_64}, ${CMAKE_SYSTEM_PROCESSOR} ${CPU_ARCH}")

if(UNIX)
  if(NOT APPLE)
    set(SYS_LINUX 1)
  endif()
else()
  set(SYS_LINUX 0)
endif()

if(WIN32)
set(SYS_WINDOWS 1)
else()
set(SYS_WINDOWS 0)
endif()

set(EXTRA_CFLAGS_LIST "")
if(UNIX)
  if(COMPILES_GNU99)
    list(APPEND EXTRA_CFLAGS_LIST -std=gnu99 -D_GNU_SOURCE)
  elseif(COMPILES_C99)
    list(APPEND EXTRA_CFLAGS_LIST -std=c99 -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE)
  elseif()
    message(FATAL_ERROR "non c99 complient compiler found")
  endif()
  if(HAS_NOMAYBE_UNINITIALISED)
    list(APPEND EXTRA_CFLAGS_LIST -Wno-maybe-uninitialized)
  endif()

  if(HAS_SHADOW)
    list(APPEND EXTRA_CFLAGS_LIST -Wshadow)
  endif()

  if(HAS_ALL)
    list(APPEND EXTRA_CFLAGS_LIST -Wall)
  endif()

  if(HAS_FAST_MATH)
    list(APPEND EXTRA_CFLAGS_LIST -ffast-math)
  endif()

  #TODO: maybe not needed as it could be controlled by cmake-variables
  if(HAS_M64)
    list(APPEND EXTRA_CFLAGS_LIST -m64)
  endif()

  if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
    if(HAS_O3)
      list(APPEND EXTRA_CFLAGS_LIST -O3)
    endif()
  else()
    if(HAS_G)
      list(APPEND EXTRA_CFLAGS_LIST -g)
    endif()
  endif()

  if(HAS_PREF_STACK_BOUNDARY5)
    list(APPEND EXTRA_CFLAGS_LIST -mpreferred-stack-boundary=5)
  endif()

  if(HAS_OMIT_FRAMEPOINTER)
    list(APPEND EXTRA_CFLAGS_LIST -fomit-frame-pointer)
  endif()
endif(UNIX)

string(REPLACE ";" " " EXTRA_CFLAGS "${EXTRA_CFLAGS_LIST}")
set(CMAKE_C_FLAGS ${EXTRA_CFLAGS})
if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
  set(CMAKE_C_FLAGS_RELEASE "${EXTRA_CFLAGS}")
  set(CMAKE_C_FLAGS_RELWDBG "${EXTRA_CFLAGS}")
endif()

if(${CMAKE_BUILD_TYPE} MATCHES "Debug")
  set(CMAKE_C_FLAGS_DEBUG "${EXTRA_CFLAGS}")
endif()

get_filename_component(X264_SOURCE_ROOT ${PROJECT_SOURCE_DIR}/.. ABSOLUTE)
include_directories(${X264_SOURCE_ROOT})
if(NOT HAS_GETOPT_H)
include_directories(${X264_SOURCE_ROOT}/extras)
endif()

if(CMAKE_C_COMPILER_ID MATCHES "(GNU|GCC|.*Clang)")
  SET(CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> rc <TARGET> <LINK_FLAGS> <OBJECTS>") 
  SET(CMAKE_C_ARCHIVE_APPEND "<CMAKE_AR> r  <TARGET> <LINK_FLAGS> <OBJECTS>") 
endif()

set(HAS_GETOPT_LONG TRUE)
set(HAVE_POSIXTHREAD 0)
set(HAVE_THREAD 0)
set(HAVE_BEOSTHREAD 0)
set(HAVE_WIN32THREAD 0)
      
if(WITH_THREADS)
  find_package(Threads REQUIRED)
  if(THREADS_FOUND)
    set(HAVE_THREAD 1)
    if(UNIX)
      set(HAVE_POSIXTHREAD 1)
      set(HAVE_THREAD 1)
      set(HAVE_WIN32THREAD 0)
    endif()
    if(WIN32)
      set(HAVE_POSIXTHREAD 0)
      set(HAVE_THREAD 1)
      set(HAVE_WIN32THREAD 1)
    endif()
  endif()
endif()

configure_file(${PROJECT_SOURCE_DIR}/config.h.in ${PROJECT_BINARY_DIR}/config.h)
configure_file(${PROJECT_SOURCE_DIR}/x264_config.h.in ${PROJECT_BINARY_DIR}/x264_config.h)
include_directories(${PROJECT_BINARY_DIR})
if(EXISTS ${PROJECT_BINARY_DIR}/config.h)
add_definitions(-DHAVE_CONFIG_H=1)
endif()
################################ COLLECT C SOURCES ################################

set(X264_SRCS "common/mc.c;common/predict.c;common/pixel.c;common/macroblock.c;common/frame.c;common/dct.c;common/cpu.c;common/cabac.c;common/common.c;common/osdep.c;common/rectangle.c;common/set.c;common/quant.c;common/deblock.c;common/vlc.c;common/mvpred.c;common/bitstream.c;encoder/analyse.c;encoder/me.c;encoder/ratecontrol.c;encoder/set.c;encoder/macroblock.c;encoder/cabac.c;encoder/cavlc.c;encoder/encoder.c;encoder/lookahead.c")

set(X264_SRCCLI "x264.c;input/input.c;input/timecode.c;input/raw.c;input/y4m.c;output/raw.c;output/matroska.c;output/matroska_ebml.c;output/flv.c;output/flv_bytestream.c;filters/filters.c;filters/video/video.c;filters/video/source.c;filters/video/internal.c;filters/video/resize.c;filters/video/cache.c;filters/video/fix_vfr_pts.c;filters/video/select_every.c;filters/video/crop.c;filters/video/depth.c")

if(HAS_GETOPT_LONG)
  list(APPEND X264_SRCCLI extras/getopt.c)
endif()

if(WITH_AVS)
	if(NOT HAS_DLFCN_H)
		message("unable to find dlfcn.h on your system, that is required by avs.c, skipping AVS support")
	else()
	list(APPEND X264_SRCCLI input/avs.c)
	endif()
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

PREPEND_ITEM("${X264_SRCS}" "${X264_SOURCE_ROOT}/" X264_SRCS)
PREPEND_ITEM("${X264_SRCCLI}" "${X264_SOURCE_ROOT}/" X264_SRCCLI)

add_library(x264-objects OBJECT ${X264_SRCS})
add_library(x264-appobjects OBJECT ${X264_SRCCLI})


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

PREPEND_ITEM("${ASMSRC}" "${X264_SOURCE_ROOT}/" ASMSRC)

if(NOT YASM_ROOT)
  if(DEFINED ENV{YASM_ROOT})
    set(YASM_ROOT ENV{YASM_ROOT})
  endif()
endif()

################################ COLLECT ASM APP ################################
find_program(YASM_APP NAMES yasm yasm${CMAKE_EXECUTABLE_SUFFIX} NAMES_PER_DIR HINTS ${YASM_ROOT} PATHS ${YASM_ROOT} PATH_SUFFIXES bin NO_DEFAULT_PATH)
find_program(YASM_APP NAMES yasm yasm${CMAKE_EXECUTABLE_SUFFIX})
if(NOT EXISTS ${YASM_APP})
  message(FATAL_ERROR "unable to locate yasm or yasm${CMAKE_EXECUTABLE_SUFFIX} (hint cmake for the path containing yasm by defining YASM_ROOT)")
endif()
#set(CMAKE_ASM_NASM_COMPILER ${YASM_APP})
################################ COLLECT ASM FLAGS ################################
set(ASM_FLAG_LIST -I${X264_SOURCE_ROOT} -I${X264_SOURCE_ROOT}/common/x86/ -Worphan-labels -DSTACK_ALIGNMENT=${X264_STACK_ALIGNMENT})

if(${CPU_ARCH} STREQUAL "x86_64")
  list(APPEND ASM_FLAG_LIST -DARCH_X86_64=1)
endif()
 
if(WITH_PIC)
  list(APPEND ASM_FLAG_LIST -DPIC)
  set(CMAKE_POSITION_INDEPENDENT_CODE True)
  if(CMAKE_C_COMPILER_ID MATCHES "(GNU|GCC|.*Clang)")
    
    SET(CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> rc <TARGET> <LINK_FLAGS> <OBJECTS>") 
    SET(CMAKE_C_ARCHIVE_APPEND "<CMAKE_AR> r  <TARGET> <LINK_FLAGS> <OBJECTS>")
    
  endif()

  if(HAS_PIC)
    add_definitions(-fPIC)
  endif()

else()
  set(CMAKE_POSITION_INDEPENDENT_CODE False)
endif()

if(${X264_BIT_DEPTH} EQUAL 8)
  list(APPEND ASM_FLAG_LIST -DHIGH_BIT_DEPTH=0)
endif()

list(APPEND ASM_FLAG_LIST -DBIT_DEPTH=${X264_BIT_DEPTH})
string(REPLACE ";" " " ASM_FLAGS "${ASM_FLAG_LIST}")

if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
  set(CMAKE_ASM_YASM_FLAGS_RELEASE ${ASM_FLAGS})
endif()

if(${CMAKE_BUILD_TYPE} MATCHES "Deb.*")
  set(CMAKE_ASM_YASM_FLAGS_DEBUG ${ASM_FLAGS})
endif()

#TODO: CMAKE_ASM_NASM_FLAGS_RELWITHDEBINFO
#TODO: CMAKE_ASM_NASM_FLAGS_MINSIZEREL

set(CMAKE_ASM_YASM_FLAGS "${ASM_FLAGS}")
enable_language(ASM_YASM)
message(STATUS "using asm source : ${ASMSRC}")
add_library(x264-asm OBJECT ${ASMSRC})

if(${WITH_SHARED})
  add_library(x264-shared SHARED $<TARGET_OBJECTS:x264-objects> $<TARGET_OBJECTS:x264-asm>)
  set_target_properties(x264-shared PROPERTIES OUTPUT_NAME x264)
  set_target_properties(x264-shared PROPERTIES PUBLIC_HEADER "${X264_SOURCE_ROOT}/x264.h;${PROJECT_BINARY_DIR}/x264_config.h")
  
  if(HAS_SHARED AND HAS_LINK_SYMBOLIC)
    set_target_properties(x264-shared PROPERTIES LINK_FLAGS "-shared -Wl,-Bsymbolic")
  endif()

  file(STRINGS ${X264_SOURCE_ROOT}/x264.h API_VERSION_LINE REGEX "#define X264_BUILD")
  if(API_VERSION_LINE AND NOT ${API_VERSION_LINE} EQUAL "")
    string(REPLACE "#define X264_BUILD " "" API_VERSION ${API_VERSION_LINE})
  else()
    set(API_VERSION 0)
  endif()

  if(API_VERSION AND ${API_VERSION} GREATER 0)
    set_target_properties(x264-shared PROPERTIES SOVERSION ${API_VERSION})
  endif()
  

  
  INSTALL(TARGETS x264-shared
    EXPORT x264-targets 
    LIBRARY DESTINATION lib 
    RUNTIME DESTINATION bin
    PUBLIC_HEADER DESTINATION include)

endif()
  
if(${WITH_STATIC})
  find_program(GCC_AR_APP gcc-ar)
  if(EXISTS ${GCC_AR_APP})
    set(CMAKE_AR "gcc-ar")
  endif()

  
  add_library(x264-static STATIC $<TARGET_OBJECTS:x264-objects> $<TARGET_OBJECTS:x264-asm>)
  #target_link_libraries(x264-objects x264-asm)
  set_target_properties(x264-static PROPERTIES OUTPUT_NAME x264)
  set_target_properties(x264-static PROPERTIES PUBLIC_HEADER "${X264_SOURCE_ROOT}/x264.h;${PROJECT_BINARY_DIR}/x264_config.h")
  

  INSTALL(TARGETS x264-static
    EXPORT x264-targets 
    ARCHIVE DESTINATION lib
    PUBLIC_HEADER DESTINATION include)

endif()


if(${WITH_CLI})
  
  add_executable(x264 $<TARGET_OBJECTS:x264-appobjects>)
  if(TARGET x264-static)
    target_link_libraries(x264 x264-static)
  else()
    if(TARGET x264-shared)
      target_link_libraries(x264 x264-shared)
    else()
      message(FATAL_ERROR "building the CLI app only is not supported yet")
    endif()
  endif()

  if(UNIX)
    target_link_libraries(x264 dl m)
  endif()

  if(WITH_THREADS)
    target_link_libraries(x264 Threads::Threads)
  endif()

  INSTALL(TARGETS x264
    EXPORT x264-targets 
    RUNTIME DESTINATION bin)

endif()


