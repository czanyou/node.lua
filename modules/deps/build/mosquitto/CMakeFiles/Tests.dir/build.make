# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 2.8

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list

# Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The program to use to edit the cache.
CMAKE_EDIT_COMMAND = /usr/bin/ccmake

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /mnt/c/work/node.lua.tour/modules/deps/mosquitto

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /mnt/c/work/node.lua.tour/modules/deps/build/mosquitto

# Utility rule file for Tests.

# Include the progress variables for this target.
include CMakeFiles/Tests.dir/progress.make

CMakeFiles/Tests:
	make -C /mnt/c/work/node.lua.tour/modules/deps/mosquitto/test test

Tests: CMakeFiles/Tests
Tests: CMakeFiles/Tests.dir/build.make
.PHONY : Tests

# Rule to build all files generated by this target.
CMakeFiles/Tests.dir/build: Tests
.PHONY : CMakeFiles/Tests.dir/build

CMakeFiles/Tests.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/Tests.dir/cmake_clean.cmake
.PHONY : CMakeFiles/Tests.dir/clean

CMakeFiles/Tests.dir/depend:
	cd /mnt/c/work/node.lua.tour/modules/deps/build/mosquitto && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mnt/c/work/node.lua.tour/modules/deps/mosquitto /mnt/c/work/node.lua.tour/modules/deps/mosquitto /mnt/c/work/node.lua.tour/modules/deps/build/mosquitto /mnt/c/work/node.lua.tour/modules/deps/build/mosquitto /mnt/c/work/node.lua.tour/modules/deps/build/mosquitto/CMakeFiles/Tests.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/Tests.dir/depend

