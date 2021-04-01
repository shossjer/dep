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
```
