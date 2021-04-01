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
	FULL_DOCS "Configuration type in debug configurations. Ignored by default."
	)

set(_dep_cmake_current_list_dir "${CMAKE_CURRENT_LIST_DIR}")

function(_get_dep_configuration_types outvar supports_debug)
	get_property(_nondebug DIRECTORY PROPERTY DEP_NONDEBUG_CONFIG)
	get_property(_debug DIRECTORY PROPERTY DEP_DEBUG_CONFIG)
	if(NOT "${_nondebug}")
		set(_nondebug Release)
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

function(dep_build name)
	set(_options FIND_GIT SUPPORTS_DEBUG)
	set(_multi_values BUILD_STEP CMAKE_OPTIONS CONFIGURE_STEP DOWNLOAD_STEP INSTALL_STEP UPDATE_STEP)
	cmake_parse_arguments(PARSE_ARGV 0 _parsed "${_options}" "" "${_multi_values}")
	# note we have to use the 3.7 syntax here in order to properly
	# handle empty strings as arguments, read the discussion at
	# https://gitlab.kitware.com/cmake/cmake/-/issues/16341
	# for more details

	set(_download_step "\"DOWNLOAD_COMMAND\" \"\"")
	set(_update_step "\"UPDATE_COMMAND\" \"\"")
	set(_configure_step "\"CONFIGURE_COMMAND\" \"\"")
	set(_build_step "\"BUILD_COMMAND\" \"\"")
	set(_install_step "\"INSTALL_COMMAND\" \"\"")

	if(DEFINED _parsed_DOWNLOAD_STEP)
		_join(" " _download_step "${_parsed_DOWNLOAD_STEP}")
	endif()

	if(DEFINED _parsed_UPDATE_STEP)
		_join(" " _update_step "${_parsed_UPDATE_STEP}")
	endif()

	if(DEFINED _parsed_CONFIGURE_STEP)
		_join(" " _configure_step "${_parsed_CONFIGURE_STEP}")
	endif()

	if(DEFINED _parsed_BUILD_STEP)
		_join(" " _build_step "${_parsed_BUILD_STEP}")
	endif()

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

	set(_build_dir "${CMAKE_BINARY_DIR}/dep/${name}")

	_get_dep_directory(_dep_directory)

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
	endif()
endfunction()
