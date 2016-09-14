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
option(WITH_THREADS "build with multithreading on" ON)

# if(MSVC)
  
  # option(WITH_WIN32THREADS "build with windows32 multithreading on" ON)
# else()
  # option(WITH_THREADS "build with POSIX multithreading on" ON)
  # option(WITH_WIN32THREADS "build with windows32 multithreading on" OFF)
# endif()

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
option(WITH_STATIC_RT "link to runtime statically" OFF)
if(WIN32)
	set(WITH_STATIC_RT ON)
endif()

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

#GNU related
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

#MSVC
check_c_compiler_flag(/W4 HAS_MSVC_FULLWARNINGS)
check_c_compiler_flag(/Ob2 HAS_MSVC_ALWAYSINLINE)
check_c_compiler_flag(/MP HAS_MSVC_MULTITHREADEDBUILD)

check_c_compiler_flag(/MT HAS_MSVC_MULTITHREADEDAPPRT)
check_c_compiler_flag(/MTd HAS_MSVC_MULTITHREADEDAPPDEBUGRT)
check_c_compiler_flag(/MD HAS_MSVC_MULTITHREADEDDLL)
check_c_compiler_flag(/MDd HAS_MSVC_MULTITHREADEDDLLDDEBUG)

check_c_compiler_flag(/GS- HAS_BUFFER_SECCHECK)
check_c_compiler_flag(/Oi HAS_MSVC_OPT_INTRINSICS)
check_c_compiler_flag(/Oy HAS_MSVC_OMIT_FRAMEPOINTER)
check_c_compiler_flag(/Od HAS_MSVC_NOOPT)
check_c_compiler_flag(/Ox HAS_MSVC_FASTCODE)
check_c_compiler_flag(/Zp HAS_MSVC_STRUCT_STACKALIGN)
check_c_compiler_flag(/fp:fast HAS_MSVC_FASTMATH)

check_function_exists(getopt_long HAS_GETOPT_LONG)


check_include_file(math.h HAS_MATH_H)
check_include_file(windows.h HAS_WINDOWS_H)
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
  check_C_source_compiles("#include <math.h>\nint main(){return log2f(2);}" HAS_LOG2F)
endif()

if(HAS_STD_GNU99)
  set(CMAKE_REQUIRED_FLAGS "-std=gnu99 -D_GNU_SOURCE")
  check_C_source_compiles("int main(){for( int i = 0; i < 9; i++ );;return 0;}" COMPILES_GNU99)
endif()

if(HAS_STD_C99)
  set(CMAKE_REQUIRED_FLAGS "-std=c99 -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE")
  check_C_source_compiles("int main(){for( int i = 0; i < 9; i++ );;return 0;}" COMPILES_C99)
endif()

if(HAS_MALLOC_H)
  check_C_source_compiles("#include <malloc.h>\nint main(int argc,char** argv){int* buf = (int*)memalign(8,16);}" HAS_MEMALIGN)
  check_C_source_compiles("#include <malloc.h>\nint main(int argc,char** argv){int* buf = (int*)_aligned_malloc(16,8);}" HAS_ALIGNEDMALLOC)
  if(NOT HAS_MEMALIGN)
    set(HAS_MEMALIGN 0)
  endif()
  if(NOT HAS_ALIGNEDMALLOC)
    set(HAS_ALIGNEDMALLOC 0)
  endif()
endif()

if(HAS_MMAN_H)
  check_symbol_exists(MAP_PRIVATE sys/mman.h HAS_MMAP)
  check_symbol_exists(MADV_HUGEPAGE sys/mman.h HAS_THP)
  else()
    set(HAS_THP 0)
    set(HAS_MMAP 0)
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
else(HAS_X86_INLINE_ASM)
  set(HAS_X86_INLINE_ASM 0)
  set(HAS_MMX 0)
endif(HAS_X86_INLINE_ASM)

if(MSVC AND ${HAS_X86_INLINE_ASM} EQUAL 0)
check_C_source_compiles("void main(){__asm pabsw xmm0, xmm0;}" HAS_X86_INLINE_ASM)
if(HAS_X86_INLINE_ASM)
  check_C_source_compiles("void main(){__asm pabsw xmm0, xmm0;}" HAS_MMX)
else(HAS_X86_INLINE_ASM)
  set(HAS_X86_INLINE_ASM 0)
  set(HAS_MMX 0)
endif(HAS_X86_INLINE_ASM)


if("${HAS_X86_INLINE_ASM}" EQUAL 0)

if(HAS_MSVC_OPT_INTRINSICS)
	set(CMAKE_REQUIRED_FLAGS "/Oi")
endif()
check_C_source_compiles("#include <emmintrin.h>\nint main(void){int v = 0;__m128i vreg = {0};vreg = _mm_set1_epi32(v);return v;}" HAS_MMX_FROM_INTRINSICS)
if(NOT ${HAS_MMX_FROM_INTRINSICS})
set(HAS_MMX 0)
else()
set(HAS_MMX 1)
endif()

endif()
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
  set(X264_FSEEK fseeko64)
  set(X264_FTELL ftello64)
elseif(HAS_FSEEKI64)
  set(X264_FSEEK _fseeki64)
  set(X264_FTELL _ftelli64)
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

if(MSVC)
    # disable Microsofts suggestions for proprietary secure APIs
    add_definitions(/D_CRT_SECURE_NO_WARNINGS)
	
	if(HAS_MSVC_ALWAYSINLINE)
	list(APPEND EXTRA_CFLAGS_LIST /Ob2)
	endif()
	
	if(HAS_MSVC_FULLWARNINGS)
	list(APPEND EXTRA_CFLAGS_LIST /W4)
	endif()
	
	if(HAS_MSVC_MULTITHREADEDBUILD)
	list(APPEND EXTRA_CFLAGS_LIST /MP)
	endif()
	
	if(HAS_MSVC_OMIT_FRAMEPOINTER)
	list(APPEND EXTRA_CFLAGS_LIST /Oy)
	endif()
	
	if(HAS_MSVC_FASTCODE)
	if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
	list(APPEND EXTRA_CFLAGS_LIST /Ox)
	endif()
	endif()
		
	#according to https://msdn.microsoft.com/en-us/library/aa290049(v=vs.71).aspx
	if(${ARCH_X86_64} EQUAL 1)
	set(X264_STACK_ALIGNMENT 16)
	else()
	set(X264_STACK_ALIGNMENT 4)
	endif()
	
	if(HAS_MSVC_STRUCT_STACKALIGN)
	list(APPEND EXTRA_CFLAGS_LIST /Zp${X264_STACK_ALIGNMENT})
	endif()
	
	if(HAS_MSVC_FASTMATH)
	if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
	list(APPEND EXTRA_CFLAGS_LIST /fp:fast)
	endif()
	endif()
	
	if(HAS_MSVC_FULLDEBUG)
	if(${CMAKE_BUILD_TYPE} MATCHES "(Debug|Dbg)")
	list(APPEND EXTRA_CFLAGS_LIST /Zi)
	endif()
	endif()
	
	if(${CMAKE_BUILD_TYPE} MATCHES "Debug")
	if(HAS_MSVC_NOOPT)
	list(APPEND EXTRA_CFLAGS_LIST /Od)
	endif()
	endif()
	# if(${CPU_ARCH} MATCHES "x86_64")
		# list(APPEND EXTRA_LDFLAGS_LIST /LARGEADDRESSAWARE)
		# list(APPEND EXTRA_LDFLAGS_LIST /LARGEADDRESSAWARE)
	# endif()
	
	if(HAS_BUFFER_SECCHECK)
		add_definitions(-GS-)
	endif()
	
	
	
	
	# if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
        # list(APPEND EXTRA_CFLAGS_LIST -O3)
	# else()
		# list(APPEND EXTRA_CFLAGS_LIST -g)
    # endif()
  
endif()

string(REPLACE ";" " " EXTRA_CFLAGS "${EXTRA_CFLAGS_LIST}")
string(REPLACE ";" " " EXTRA_LDFLAGS "${EXTRA_LDFLAGS_LIST}")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${EXTRA_CFLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${EXTRA_LDFLAGS}")
set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} ${EXTRA_LDFLAGS}")
if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
  set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} ${EXTRA_CFLAGS}")
  set(CMAKE_C_FLAGS_RELWDBG "${CMAKE_C_FLAGS_RELWDBG} ${EXTRA_CFLAGS}")
endif()

if(${CMAKE_BUILD_TYPE} MATCHES "Debug")
  set(CMAKE_C_FLAGS_RELWDBG "${CMAKE_C_FLAGS_RELWDBG} ${EXTRA_CFLAGS}")
  set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} ${EXTRA_CFLAGS}")
endif()

if(WIN32 OR MSVC)
set(CompilerFlags CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE)
foreach(CompilerFlag ${CompilerFlags})
	string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
endforeach()
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

#set(HAS_GETOPT_LONG TRUE)
set(HAVE_POSIXTHREAD 0)
set(HAVE_THREAD 0)
set(HAVE_BEOSTHREAD 0)
set(HAVE_WIN32THREAD 0)
      
if(WITH_THREADS)
  find_package(Threads REQUIRED)
  if(THREADS_FOUND)
    set(HAVE_THREAD 1)
    set(HAVE_POSIXTHREAD ${CMAKE_USE_PTHREADS_INIT})
    set(HAVE_WIN32THREAD ${CMAKE_USE_WIN32_THREADS_INIT})
	if(HAVE_POSIXTHREAD)
	message(STATUS "threading library found: pthreads")
	endif()
	
	if(HAVE_WIN32THREAD)
	message(STATUS "threading library found: win32threads")
	endif()
	
  else(THREADS_FOUND)
	message(STATUS "threading library NOT found")
  endif(THREADS_FOUND)
endif()

if(WITH_AVS)
	if(WIN32)
		if(HAS_WINDOWS_H)
			set(HAS_AVS 1)
			set(USE_AVISYNTH 1)
		else()
			set(HAS_AVS 0)
		endif()
    else(WIN32)
		if(HAS_DLFCN_H)
			set(HAS_AVS 1)
			set(USE_AVXSYNTH 1)
		else()
			set(HAS_AVS 0)
		endif()
	endif(WIN32)
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

message(STATUS "getopt_long found? .${HAS_GETOPT_LONG}.")
if(NOT "${HAS_GETOPT_LONG}" EQUAL "")
  list(APPEND X264_SRCCLI extras/getopt.c)
endif()


if(HAS_AVS)
list(APPEND X264_SRCCLI input/avs.c)
endif()

if(WITH_FFMS)
  list(APPEND X264_SRCS input/ffms.c)
endif()

if(HAVE_THREAD)
  list(APPEND X264_SRCCLI input/thread.c)
  list(APPEND X264_SRCS common/threadpool.c)
endif()

if(HAVE_WIN32THREAD)
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
if(MSVC)
	set(YASM_SEARCH_NAMES yasm yasm${CMAKE_EXECUTABLE_SUFFIX})
	#set(YASM_SEARCH_NAMES vsyasm vsyasm${CMAKE_EXECUTABLE_SUFFIX})
else()	
	set(YASM_SEARCH_NAMES yasm yasm${CMAKE_EXECUTABLE_SUFFIX})
endif()	

find_program(YASM_APP NAMES ${YASM_SEARCH_NAMES} HINTS ${YASM_ROOT} PATHS ${YASM_ROOT} PATH_SUFFIXES bin NO_DEFAULT_PATH)
find_program(YASM_APP NAMES ${YASM_SEARCH_NAMES})
if(NOT EXISTS ${YASM_APP})
  message(FATAL_ERROR "unable to locate yasm or yasm${CMAKE_EXECUTABLE_SUFFIX} (hint cmake for the path containing yasm by defining YASM_ROOT)")
endif()

set(CMAKE_ASM_YASM_COMPILER ${YASM_APP})
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
set(CMAKE_ASM_YASM_FLAGS "${ASM_FLAGS}")

if(${CMAKE_BUILD_TYPE} MATCHES "Rel.*")
  set(CMAKE_ASM_YASM_FLAGS_RELEASE ${ASM_FLAGS})
endif()

if(${CMAKE_BUILD_TYPE} MATCHES "Deb.*")
  set(CMAKE_ASM_YASM_FLAGS_DEBUG ${ASM_FLAGS})
endif()

#TODO: CMAKE_ASM_NASM_FLAGS_RELWITHDEBINFO
#TODO: CMAKE_ASM_NASM_FLAGS_MINSIZEREL


enable_language(ASM_YASM)
message(STATUS "using asm compiler : ${CMAKE_ASM_YASM_COMPILER} (${YASM_APP})")
message(STATUS "using asm source   : ${ASMSRC}")
source_group(ASM FILES ${ASMSRC})
add_library(x264-asm OBJECT ${ASMSRC})
#on Windows we need to call yasm manually :(
if(MSVC)
if( CMAKE_SIZEOF_VOID_P MATCHES 8 )
    list(APPEND ASM_FLAG_LIST -DARCH_X86_64=1)
    if(APPLE)
        list(APPEND ASM_FLAG_LIST -f macho64 -m amd64 -DPREFIX)
    elseif(UNIX AND NOT CYGWIN)
        list(APPEND ASM_FLAG_LIST -f elf64 -m amd64)
    else()
        list(APPEND ASM_FLAG_LIST -f win64 -m amd64)
    endif()
else()
    list(APPEND ASM_FLAG_LIST -DARCH_X86_64=0)
    if(APPLE)
        list(APPEND ASM_FLAG_LIST -f macho -DPREFIX)
    elseif(UNIX AND NOT CYGWIN)
        list(APPEND ASM_FLAG_LIST -f elf32)
    else()
        list(APPEND ASM_FLAG_LIST -f win32 -DPREFIX)
    endif()
endif()


message(STATUS "using asm flags    : ${YASM_APP} ${ASM_FLAG_LIST} foo.asm -o foo.asm.obj")
foreach(_SRC IN LISTS ASMSRC)
get_filename_component(_SRC_NAMESTUB ${_SRC} NAME_WE)
get_filename_component(_SRC_EXT ${_SRC} EXT)
set(_OBJ ${PROJECT_BINARY_DIR}/${_SRC_NAMESTUB}.obj)

            list(APPEND ASMOBJS ${_OBJ})
            add_custom_command(
                OUTPUT ${_OBJ}
                COMMAND ${YASM_APP} ARGS ${ASM_FLAG_LIST} ${_SRC} -o ${_OBJ}
                DEPENDS ${_SRC})
				
endforeach()
endif()


if(${WITH_SHARED})
	if(NOT MSVC)
		add_library(x264-shared SHARED $<TARGET_OBJECTS:x264-objects> $<TARGET_OBJECTS:x264-asm>)
	else()
		add_library(x264-shared SHARED $<TARGET_OBJECTS:x264-objects> ${ASMOBJS} ${ASMSRCS})
	endif()
  
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
  
  if(WITH_THREADS)
    target_link_libraries(x264-shared Threads::Threads)
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

  if(NOT MSVC)
  add_library(x264-static STATIC $<TARGET_OBJECTS:x264-objects> $<TARGET_OBJECTS:x264-asm>)
  else()
  add_library(x264-static STATIC $<TARGET_OBJECTS:x264-objects> ${ASMOBJS} ${ASMSRCS})
  endif()
  #target_link_libraries(x264-objects x264-asm)
  set_target_properties(x264-static PROPERTIES OUTPUT_NAME x264)
  set_target_properties(x264-static PROPERTIES PUBLIC_HEADER "${X264_SOURCE_ROOT}/x264.h;${PROJECT_BINARY_DIR}/x264_config.h")
  
  if(WITH_THREADS)
    target_link_libraries(x264-static Threads::Threads)
  endif()
  
  INSTALL(TARGETS x264-static
    EXPORT x264-targets 
    ARCHIVE DESTINATION lib
    PUBLIC_HEADER DESTINATION include)

endif()


if(${WITH_CLI})
  
  #add_executable(x264 $<TARGET_OBJECTS:x264-appobjects>)
  add_executable(x264 ${X264_SRCCLI})
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


