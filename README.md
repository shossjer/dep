# DIY External Project

With dep you can download, build, and install projects using the
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
      SUPPORTS_DEBUG

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
   SUPPORTS_DEBUG

   DEPENDS
   my_prebuilt_target

   FILES
   someheader1.h
   someheader2.h

   LIBS
   somelib
   )

target_link_libraries(myproject INTERFACE my_cmake_dependency)
```

## Customization

There are three properties that can be set in order to modify the
functionality of dep.

* `DEP_DIRECTORY` - of type `DIRECTORY`

  The path to where dep will put _all the stuff_. This directory
  serves as both a working directory (where downloads, source
  unpacking, and build data is located) as well as the install
  directory (where the dependencies are all installed to). Unless
  explicitly set, it will default to `"${CMAKE_SOURCE_DIR}/dep"`.

  Protip: If you build your project with multiple compilers (e.g. gcc
  and clang), or if you are on Windows and want to use both msvc and
  your favorite compiler under wsl, do something like the following
  ```
  set_property(DIRECTORY PROPERTY DEP_DIRECTORY "${CMAKE_SOURCE_DIR}/dep/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}")
  ```

  That way, the dependencies will not collide between your various
  build setups.

* `DEP_NONDEBUG_CONFIG` - of type `DIRECTORY`

  The build type that should be used for non-debug builds. This is the
  version of the dependency that will be used by default. Unless
  explicitly set, it will default to `Release`.

* `DEP_DEBUG_CONFIG` - of type `DIRECTORY`

  The build type that should be used for debug builds. This is the
  version of the dependency that will be used whenever the dependency
  is marked with `SUPPORTS_DEBUG` and your project is built with a
  build type that is listed in the `GLOBAL` property
  `DEBUG_CONFIGURATIONS`. Unless explicitly set, it will default to
  `Debug`.

## Quirks

This project is still in its early stages of development, being
developed by trial an error, and as a result contains a lot of _hacky
stuff_. Please have a look at the arguments-parsing in `dep_build` for
a complete list of the available hacks. When the hacks have proven
themselves useful, they will be upgraded to features and listed more
publicly on this page somewhere.
