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
include ubus/examples/CMakeFiles/client.dir/depend.make

# Include the progress variables for this target.
include ubus/examples/CMakeFiles/client.dir/progress.make

# Include the compile flags for this target's objects.
include ubus/examples/CMakeFiles/client.dir/flags.make

ubus/examples/CMakeFiles/client.dir/client.c.o: ubus/examples/CMakeFiles/client.dir/flags.make
ubus/examples/CMakeFiles/client.dir/client.c.o: ../ubus/examples/client.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/ubus/build/CMakeFiles $(CMAKE_PROGRESS_1)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object ubus/examples/CMakeFiles/client.dir/client.c.o"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/client.dir/client.c.o   -c /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples/client.c

ubus/examples/CMakeFiles/client.dir/client.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/client.dir/client.c.i"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples/client.c > CMakeFiles/client.dir/client.c.i

ubus/examples/CMakeFiles/client.dir/client.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/client.dir/client.c.s"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples/client.c -o CMakeFiles/client.dir/client.c.s

ubus/examples/CMakeFiles/client.dir/client.c.o.requires:
.PHONY : ubus/examples/CMakeFiles/client.dir/client.c.o.requires

ubus/examples/CMakeFiles/client.dir/client.c.o.provides: ubus/examples/CMakeFiles/client.dir/client.c.o.requires
	$(MAKE) -f ubus/examples/CMakeFiles/client.dir/build.make ubus/examples/CMakeFiles/client.dir/client.c.o.provides.build
.PHONY : ubus/examples/CMakeFiles/client.dir/client.c.o.provides

ubus/examples/CMakeFiles/client.dir/client.c.o.provides.build: ubus/examples/CMakeFiles/client.dir/client.c.o

ubus/examples/CMakeFiles/client.dir/count.c.o: ubus/examples/CMakeFiles/client.dir/flags.make
ubus/examples/CMakeFiles/client.dir/count.c.o: ../ubus/examples/count.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/ubus/build/CMakeFiles $(CMAKE_PROGRESS_2)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object ubus/examples/CMakeFiles/client.dir/count.c.o"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/client.dir/count.c.o   -c /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples/count.c

ubus/examples/CMakeFiles/client.dir/count.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/client.dir/count.c.i"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples/count.c > CMakeFiles/client.dir/count.c.i

ubus/examples/CMakeFiles/client.dir/count.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/client.dir/count.c.s"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples/count.c -o CMakeFiles/client.dir/count.c.s

ubus/examples/CMakeFiles/client.dir/count.c.o.requires:
.PHONY : ubus/examples/CMakeFiles/client.dir/count.c.o.requires

ubus/examples/CMakeFiles/client.dir/count.c.o.provides: ubus/examples/CMakeFiles/client.dir/count.c.o.requires
	$(MAKE) -f ubus/examples/CMakeFiles/client.dir/build.make ubus/examples/CMakeFiles/client.dir/count.c.o.provides.build
.PHONY : ubus/examples/CMakeFiles/client.dir/count.c.o.provides

ubus/examples/CMakeFiles/client.dir/count.c.o.provides.build: ubus/examples/CMakeFiles/client.dir/count.c.o

# Object files for target client
client_OBJECTS = \
"CMakeFiles/client.dir/client.c.o" \
"CMakeFiles/client.dir/count.c.o"

# External object files for target client
client_EXTERNAL_OBJECTS =

ubus/examples/client: ubus/examples/CMakeFiles/client.dir/client.c.o
ubus/examples/client: ubus/examples/CMakeFiles/client.dir/count.c.o
ubus/examples/client: ubus/examples/CMakeFiles/client.dir/build.make
ubus/examples/client: ubus/libubus.so
ubus/examples/client: libubox/libubox.so
ubus/examples/client: ubus/examples/CMakeFiles/client.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --red --bold "Linking C executable client"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/client.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
ubus/examples/CMakeFiles/client.dir/build: ubus/examples/client
.PHONY : ubus/examples/CMakeFiles/client.dir/build

ubus/examples/CMakeFiles/client.dir/requires: ubus/examples/CMakeFiles/client.dir/client.c.o.requires
ubus/examples/CMakeFiles/client.dir/requires: ubus/examples/CMakeFiles/client.dir/count.c.o.requires
.PHONY : ubus/examples/CMakeFiles/client.dir/requires

ubus/examples/CMakeFiles/client.dir/clean:
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples && $(CMAKE_COMMAND) -P CMakeFiles/client.dir/cmake_clean.cmake
.PHONY : ubus/examples/CMakeFiles/client.dir/clean

ubus/examples/CMakeFiles/client.dir/depend:
	cd /mnt/c/work/node.lua.tour/modules/ubus/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mnt/c/work/node.lua.tour/modules/ubus /mnt/c/work/node.lua.tour/modules/ubus/ubus/examples /mnt/c/work/node.lua.tour/modules/ubus/build /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples /mnt/c/work/node.lua.tour/modules/ubus/build/ubus/examples/CMakeFiles/client.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : ubus/examples/CMakeFiles/client.dir/depend
