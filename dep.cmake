cmake_minimum_required(VERSION 3.7)

define_property(DIRECTORY PROPERTY "DEP_DIRECTORY" INHERITED
	BRIEF_DOCS "Directory where dependencies will be installed to."
	FULL_DOCS "Directory where dependencies will be installed to."
	)

define_property(DIRECTORY PROPERTY "DEP_NONDEBUG_CONFIG" INHERITED
	BRIEF_DOCS "Configuration type in non-debug configurations."
	FULL_DOCS "Configuration type in non-debug configurations. Defaults to Release."
	)

define_property(DIRECTORY PROPERTY "DEP_DEBUG_CONFIG" INHERITED
	BRIEF_DOCS "Configuration type in debug configurations."
	FULL_DOCS "Configuration type in debug configurations. Defaults to Debug."
	)

set(_dep_cmake_current_list_dir "${CMAKE_CURRENT_LIST_DIR}")

function(_get_dep_configuration_types outvar supports_debug)
	get_property(_nondebug DIRECTORY PROPERTY DEP_NONDEBUG_CONFIG)
	get_property(_debug DIRECTORY PROPERTY DEP_DEBUG_CONFIG)
	if(NOT "${_nondebug}")
		set(_nondebug Release)
	endif()
	if(NOT "${_debug}")
		set(_debug Debug)
	endif()

	if("${_debug}" STREQUAL "${_nondebug}")
		message(WARNING "DEP_DEBUG_CONFIG equals DEP_NONDEBUG_CONFIG, will ignore debug configuration")
		set(_debug "")
	endif()

	if(_debug AND supports_debug)
		set(${outvar} ${_nondebug} ${_debug} PARENT_SCOPE)
	else()
		set(${outvar} ${_nondebug} PARENT_SCOPE)
	endif()
endfunction()

function(_get_dep_build_type outvar supports_debug)
	get_property(_nondebug DIRECTORY PROPERTY DEP_NONDEBUG_CONFIG)
	get_property(_debug DIRECTORY PROPERTY DEP_DEBUG_CONFIG)
	if(NOT "${_nondebug}")
		set(_nondebug Release)
	endif()

	if("${_debug}" STREQUAL "${_nondebug}")
		message(WARNING "DEP_DEBUG_CONFIG equals DEP_NONDEBUG_CONFIG, will ignore debug configuration")
		set(_debug "")
	endif()

	get_property(_debug_configurations GLOBAL PROPERTY DEBUG_CONFIGURATIONS)
	if(_debug AND supports_debug AND "${CMAKE_BUILD_TYPE}" IN_LIST _debug_configurations)
		set(${outvar} ${_debug} PARENT_SCOPE)
	else()
		set(${outvar} ${_nondebug} PARENT_SCOPE)
	endif()
endfunction()

macro(_get_dep_directory outvar)
	get_property(${outvar} DIRECTORY PROPERTY DEP_DIRECTORY)
	if(NOT ${outvar})
		set(${outvar} "${CMAKE_SOURCE_DIR}/dep")
	endif()
endmacro()

function(_quote outvar)
	set(_str "")
	foreach(_arg IN LISTS ARGN)
		if(_str)
			set(_str "${_str}\;${_arg}")
		else()
			set(_str "${_arg}")
		endif()
	endforeach()
	set(${outvar} "\"${_str}\"" PARENT_SCOPE)
endfunction()

# 3.12 string(JOIN ...)
# except this function quotes all arguments
function(_join glue outvar)
	set(_str "")
	foreach(_arg IN LISTS ARGN)
		if(_str)
			set(_str "${_str}${glue}\"${_arg}\"")
		else()
			set(_str "\"${_arg}\"")
		endif()
	endforeach()
	set(${outvar} "${_str}" PARENT_SCOPE)
endfunction()

function(_filter_system var)
	# todo turns out that CMAKE_SYSTEM_PROCESSOR is not _really_
	# supported on Windows (they say it is because you are expected to
	# set it yourself :joy: somehow a very typical CMake-solution to
	# the problem), anyway, an option might be to look at the
	# environment variable PROCESSOR_ARCHITECTURE
	#
	# https://gitlab.kitware.com/cmake/cmake/-/issues/15170
	set(_systems Linux_x86_64 Windows_AMD64)
	set(_system "${CMAKE_SYSTEM_NAME}_${CMAKE_SYSTEM_PROCESSOR}")

	if(DEFINED ${var})
		set(_str "")
		set(_use True)
		foreach(_arg IN LISTS ${var})
			if("${_arg}" IN_LIST _systems)
				if("${_arg}" STREQUAL "${_system}")
					set(_use True)
				else()
					set(_use False)
				endif()
			elseif(_use)
				set(_str "${_str};${_arg}")
			endif()
		endforeach()
		if(_str)
			string(SUBSTRING "${_str}" 1 -1 _str)
			set(${var} "${_str}" PARENT_SCOPE)
		else()
			unset(${var} PARENT_SCOPE)
		endif()
	endif()
endfunction()

function(dep_build name)
	set(_options FIND_GIT POLICY_CMP0097 SUPPORTS_DEBUG)
	set(_multi_values BUILD_STEP CMAKE_OPTIONS CONFIGURE_STEP DOWNLOAD_STEP INSTALL_STEP UPDATE_STEP)
	cmake_parse_arguments(PARSE_ARGV 0 _parsed "${_options}" "" "${_multi_values}")
	# note we have to use the 3.7 syntax here in order to properly
	# handle empty strings as arguments, read the discussion at
	# https://gitlab.kitware.com/cmake/cmake/-/issues/16341
	# for more details

	get_property(_packaged DIRECTORY PROPERTY DEP_PACKAGED_${name})
	if(_packaged)
		return()
	endif()

	set(_download_step "\"DOWNLOAD_COMMAND\" \"\"")
	set(_update_step "\"UPDATE_COMMAND\" \"\"")
	set(_configure_step "\"CONFIGURE_COMMAND\" \"\"")
	set(_build_step "\"BUILD_COMMAND\" \"\"")
	set(_install_step "\"INSTALL_COMMAND\" \"\"")

	_filter_system(_parsed_DOWNLOAD_STEP)
	if(DEFINED _parsed_DOWNLOAD_STEP)
		_join(" " _download_step "${_parsed_DOWNLOAD_STEP}")
	endif()

	_filter_system(_parsed_UPDATE_STEP)
	if(DEFINED _parsed_UPDATE_STEP)
		_join(" " _update_step "${_parsed_UPDATE_STEP}")
	endif()

	_filter_system(_parsed_CONFIGURE_STEP)
	if(DEFINED _parsed_CONFIGURE_STEP)
		_join(" " _configure_step "${_parsed_CONFIGURE_STEP}")
	endif()

	_filter_system(_parsed_BUILD_STEP)
	if(DEFINED _parsed_BUILD_STEP)
		_join(" " _build_step "${_parsed_BUILD_STEP}")
	endif()

	_filter_system(_parsed_INSTALL_STEP)
	if(DEFINED _parsed_INSTALL_STEP)
		_join(" " _install_step "${_parsed_INSTALL_STEP}")
	endif()

	if(DEFINED _parsed_CMAKE_OPTIONS)
		set(_initial_cache "")
		get_cmake_property(_cache_variables CACHE_VARIABLES)
		foreach(_cache_variable IN ITEMS ${_cache_variables})
			if("${_cache_variable}" MATCHES "^CMAKE_" AND
					NOT "${_cache_variable}" MATCHES "^CMAKE_CACHE" AND
					NOT "${_cache_variable}" MATCHES "^CMAKE_PLATFORM_" AND
					NOT "${_cache_variable}" MATCHES "^CMAKE_PROJECT_" AND
					NOT "${_cache_variable}" MATCHES "^CMAKE_SIZEOF_" AND
					NOT "${_cache_variable}" STREQUAL "CMAKE_HOME_DIRECTORY" AND
					NOT "${_cache_variable}" STREQUAL "CMAKE_NUMBER_OF_MAKEFILES" AND
					NOT "${_cache_variable}" STREQUAL "CMAKE_INSTALL_PREFIX" AND # we add this in CmakeLists.txt.in
					NOT "${_cache_variable}" STREQUAL "CMAKE_PREFIX_PATH") # we add this in CmakeLists.txt.in
				get_property(_type CACHE ${_cache_variable} PROPERTY TYPE)
				_quote(_quoted_value ${${_cache_variable}})
				set(_initial_cache "${_initial_cache}set(${_cache_variable} ${_quoted_value} CACHE ${_type} \"Initial cache\")\n")
			endif()
		endforeach()

		set(_initial_cache_file "${CMAKE_BINARY_DIR}/dep/${name}/initial_cache.cmake")
		file(WRITE ${_initial_cache_file} ${_initial_cache})

		_join(" " _configure_step CONFIGURE_COMMAND \$\{CMAKE_COMMAND\} -C "${_initial_cache_file}" -DCMAKE_PREFIX_PATH=\$\{_install_prefix\} -DCMAKE_INSTALL_PREFIX=\$\{_install_prefix\} "${_parsed_CMAKE_OPTIONS}" \$\{_source_dir\})
		set(_build_step "")
		set(_install_step "")
	endif()

	_get_dep_directory(_dep_directory)

	set(_build_dir "${_dep_directory}/.build/${name}")

	configure_file(
		"${_dep_cmake_current_list_dir}/CMakeLists.txt.in"
		"${_build_dir}/CMakeLists.txt"
		@ONLY
		)

	if(DEFINED CMAKE_CONFIGURATION_TYPES)
		_get_dep_configuration_types(_configs "${_parsed_SUPPORTS_DEBUG}")

		execute_process(
			COMMAND ${CMAKE_COMMAND} "-DCMAKE_CONFIGURATION_TYPES:STRING=${_configs}" .
			WORKING_DIRECTORY ${_build_dir}
			)

		foreach(_config IN LISTS _configs)
			execute_process(
				COMMAND ${CMAKE_COMMAND} --build . --config ${_config}
				WORKING_DIRECTORY ${_build_dir}
				)

			set_property(DIRECTORY PROPERTY DEP_BUILT_${name}_${_config} TRUE)
		endforeach()
	elseif(DEFINED CMAKE_BUILD_TYPE)
		_get_dep_build_type(_config "${_parsed_SUPPORTS_DEBUG}")

		execute_process(
			COMMAND ${CMAKE_COMMAND} . -DCMAKE_BUILD_TYPE=${_config}
			WORKING_DIRECTORY ${_build_dir}
			)

		execute_process(
			COMMAND ${CMAKE_COMMAND} --build .
			WORKING_DIRECTORY ${_build_dir}
			)

		set_property(DIRECTORY PROPERTY DEP_BUILT_${name}_${_config} TRUE)
	endif()
endfunction()

function(dep_package name target)
	set(_options IGNORE_SYSTEM SUPPORTS_DEBUG)
	set(_multi_values DEPENDS FILES LIBS)
	cmake_parse_arguments(_parsed "${_options}" "" "${_multi_values}" ${ARGN})

	get_property(_packaged DIRECTORY PROPERTY DEP_PACKAGED_${name})
	if(_packaged)
		return()
	endif()

	_filter_system(_parsed_DEPENDS)
	_filter_system(_parsed_FILES)
	_filter_system(_parsed_LIBS)

	string(TOUPPER "${name}" _big_name)

	_get_dep_directory(_dep_directory)

	if(DEFINED CMAKE_CONFIGURATION_TYPES)
		_get_dep_configuration_types(_configs "${_parsed_SUPPORTS_DEBUG}")
	elseif(DEFINED CMAKE_BUILD_TYPE)
		_get_dep_build_type(_configs "${_parsed_SUPPORTS_DEBUG}")
	endif()

	set(_valid True)
	foreach(_config IN ITEMS ${_configs})
		get_property(_built DIRECTORY PROPERTY DEP_BUILT_${name}_${_config})
		if("${_built}" OR "${_parsed_IGNORE_SYSTEM}")
			set(_file_paths PATHS "${_dep_directory}/${_config}/include" NO_DEFAULT_PATH)
			set(_lib_paths PATHS "${_dep_directory}/${_config}/lib" NO_DEFAULT_PATH)
		else()
			set(_file_paths)
			set(_lib_paths)
		endif()

		string(TOUPPER "${_config}" _big_config)

		set(_found_all_files True)
		foreach(_file IN ITEMS ${_parsed_FILES})
			string(TOUPPER "${_file}" _big_file)
			string(MAKE_C_IDENTIFIER "${_big_file}" _c_file)

			find_file(FILE_${_c_file}_${_big_config} "${_file}" ${_file_paths})

			if(FILE_${_c_file}_${_big_config})
				message(STATUS "Looking for ${name} - ${FILE_${_c_file}_${_big_config}}")
			else()
				message(STATUS "Looking for ${name} - MISSING ${_file}")

				set(_found_all_files False)
			endif()
		endforeach()
		if(NOT _found_all_files)
			set(_valid False)
		endif()

		if(_parsed_LIBS)
			set(_found_all_libs True)
			foreach(_lib IN ITEMS ${_parsed_LIBS})
				string(TOUPPER "${_lib}" _big_lib)
				string(MAKE_C_IDENTIFIER "${_big_lib}" _c_lib)

				find_library(LIBRARY_${_c_lib}_${_big_config} "${_lib}" ${_lib_paths})

				if(LIBRARY_${_c_lib}_${_big_config})
					message(STATUS "Looking for ${name} - ${LIBRARY_${_c_lib}_${_big_config}}")
				else()
					message(STATUS "Looking for ${name} - MISSING ${_lib}")

					set(_found_all_libs False)
				endif()
			endforeach()
			if(NOT _found_all_libs)
				set(_valid False)
			endif()
		endif()
	endforeach()

	foreach(_dep IN ITEMS ${_parsed_DEPENDS})
		if(NOT TARGET ${_dep})
			set(_valid False)
		endif()
	endforeach()

	if(_valid)
		foreach(_config IN ITEMS ${_configs})
			string(TOUPPER "${_config}" _big_config)

			add_library(${target}_${_config} INTERFACE)

			foreach(_file IN ITEMS ${_parsed_FILES})
				string(TOUPPER "${_file}" _big_file)
				string(MAKE_C_IDENTIFIER "${_big_file}" _c_file)

				string(REGEX REPLACE "/${_file}$" "" _directory "${FILE_${_c_file}_${_big_config}}")

				target_include_directories(${target}_${_config} INTERFACE "${_directory}")
			endforeach()

			foreach(_lib IN ITEMS ${_parsed_LIBS})
				string(TOUPPER "${_lib}" _big_lib)
				string(MAKE_C_IDENTIFIER "${_big_lib}" _c_lib)

				target_link_libraries(${target}_${_config} INTERFACE "${LIBRARY_${_c_lib}_${_big_config}}")
			endforeach()
		endforeach()

		add_library(${target} INTERFACE)

		foreach(_dep IN ITEMS ${_parsed_DEPENDS})
			target_link_libraries(${target} INTERFACE ${_dep})
		endforeach()

		if(DEFINED CMAKE_CONFIGURATION_TYPES)
			list(LENGTH _configs _configs_length)
			if(_configs_length EQUAL 2)
				list(GET _configs 0 _config0)
				list(GET _configs 1 _config1)
				target_link_libraries(${target} INTERFACE optimized ${target}_${_config0} debug ${target}_${_config1})
			else()
				target_link_libraries(${target} INTERFACE ${target}_${_configs})
			endif()
		else()
			target_link_libraries(${target} INTERFACE ${target}_${_configs})
		endif()

		set_property(DIRECTORY PROPERTY DEP_PACKAGED_${name} TRUE)
	endif()
endfunction()
