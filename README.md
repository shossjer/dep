# DIY External Project

With `dep` you can download, build, and install projects using the
familiar ExternalProject syntax at configuration time.

## But why?

* FetchContent - https://cmake.org/cmake/help/latest/module/FetchContent.html

  CMake 3.11 introduced the module FetchContent which at a first
  glance does exactly what this project aims at. However, instead of
  building and installing libraries it makes other (CMake) projects
  available to be built as part of your own build setup. (If this is
  an incorrect summary of FetchContent, please tell me!)

* ExternalProject - https://cmake.org/cmake/help/latest/module/ExternalProject.html

  When CMake was kind of new and very awkward to use, it at least had
  the module ExternalProject. It is great except it does everything at
  build time which is a huge flaw since what you should be using CMake
  for is to detect dependencies at configure time. This project fixes
  that flaw.

## Alternatives?

* Hunter - https://github.com/cpp-pm/hunter

  A package manager that has been around since 2013 (give or take). I
  have yet to spend some actual time with it.

## Examples!

```
option(BUILD_PREBUILTLIB "Build a prebuilt lib" ON)
if(BUILD_PREBUILTLIB)
   dep_build(libprebuilt
      DOWNLOAD_STEP
      URL "https://no.virus.promiz/releases/prebuiltlib.zip"
      TIMEOUT 10

      INSTALL_STEP
      INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_if_different "\$\{_source_dir\}/prebuilt.h" "\$\{_install_prefix\}/include"
      Linux_x86_64
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "\$\{_source_dir\}/liblin64.a" "\$\{_install_prefix\}/lib"
      Windows_AMD64
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "\$\{_source_dir\}/libwin64.lib" "\$\{_install_prefix\}/lib"
      )
endif()

dep_package(libprebuilt my_prebuilt_target
   FILES
   prebuilt.h

   LIBS
   Linux_x86_64 liblin64.a
   Windows_AMD64 libwin64.lib
   )

option(BUILD_SOMECMAKEPROJECT "Build some CMake project that I need" ON)
if(BUILD_SOMECMAKEPROJECT)
   dep_build(somename
      DOWNLOAD_STEP
      GIT_REPOSITORY "https://github.com/myfavoritedeveloper/someproject.git"
      GIT_TAG "1.2.3"
      GIT_SHALLOW True

      CMAKE_OPTIONS
      -DSOME_SETTING=OFF
      -DBUT_I_DO_NEED_THIS=ON
      )
endif()

dep_package(somename my_cmake_dependency
   DEPENDS
   my_prebuilt_target

   FILES
   someheader1.h
   someheader2.h

   LIBS
   somelib
   )
```
