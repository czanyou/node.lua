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
CMAKE_SOURCE_DIR = /mnt/c/work/node.lua.tour/modules/ubus

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /mnt/c/work/node.lua.tour/modules/ubus/build

# Include any dependencies generated for this target.
include uci/CMakeFiles/ucli.dir/depend.make

# Include the progress variables for this target.
include uci/CMakeFiles/ucli.dir/progress.make

# Include the compile flags for this target's objects.
include uci/CMakeFiles/ucli.dir/flags.make

uci/CMakeFiles/ucli.dir/cli.c.o: uci/CMakeFiles/ucli.dir/flags.make
uci/CMakeFiles/ucli.dir/cli.c.o: ../uci/cli.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/ubus/build/CMakeFiles $(CMAKE_PROGRESS_1)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object uci/CMakeFiles/ucli.dir/cli.c.o"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/uci && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ucli.dir/cli.c.o   -c /mnt/c/work/node.lua.tour/modules/ubus/uci/cli.c

uci/CMakeFiles/ucli.dir/cli.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ucli.dir/cli.c.i"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/uci && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/ubus/uci/cli.c > CMakeFiles/ucli.dir/cli.c.i

uci/CMakeFiles/ucli.dir/cli.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ucli.dir/cli.c.s"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/uci && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/ubus/uci/cli.c -o CMakeFiles/ucli.dir/cli.c.s

uci/CMakeFiles/ucli.dir/cli.c.o.requires:
.PHONY : uci/CMakeFiles/ucli.dir/cli.c.o.requires

uci/CMakeFiles/ucli.dir/cli.c.o.provides: uci/CMakeFiles/ucli.dir/cli.c.o.requires
	$(MAKE) -f uci/CMakeFiles/ucli.dir/build.make uci/CMakeFiles/ucli.dir/cli.c.o.provides.build
.PHONY : uci/CMakeFiles/ucli.dir/cli.c.o.provides

uci/CMakeFiles/ucli.dir/cli.c.o.provides.build: uci/CMakeFiles/ucli.dir/cli.c.o

# Object files for target ucli
ucli_OBJECTS = \
"CMakeFiles/ucli.dir/cli.c.o"

# External object files for target ucli
ucli_EXTERNAL_OBJECTS =

uci/uci: uci/CMakeFiles/ucli.dir/cli.c.o
uci/uci: uci/CMakeFiles/ucli.dir/build.make
uci/uci: uci/libuci.so
uci/uci: libubox/libubox.so
uci/uci: uci/CMakeFiles/ucli.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --red --bold "Linking C executable uci"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/uci && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/ucli.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
uci/CMakeFiles/ucli.dir/build: uci/uci
.PHONY : uci/CMakeFiles/ucli.dir/build

uci/CMakeFiles/ucli.dir/requires: uci/CMakeFiles/ucli.dir/cli.c.o.requires
.PHONY : uci/CMakeFiles/ucli.dir/requires

uci/CMakeFiles/ucli.dir/clean:
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/uci && $(CMAKE_COMMAND) -P CMakeFiles/ucli.dir/cmake_clean.cmake
.PHONY : uci/CMakeFiles/ucli.dir/clean

uci/CMakeFiles/ucli.dir/depend:
	cd /mnt/c/work/node.lua.tour/modules/ubus/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mnt/c/work/node.lua.tour/modules/ubus /mnt/c/work/node.lua.tour/modules/ubus/uci /mnt/c/work/node.lua.tour/modules/ubus/build /mnt/c/work/node.lua.tour/modules/ubus/build/uci /mnt/c/work/node.lua.tour/modules/ubus/build/uci/CMakeFiles/ucli.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : uci/CMakeFiles/ucli.dir/depend

