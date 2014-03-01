#!/usr/bin/env tclsh

package require http

proc map {lambdaExpression list} {
    set res {}
    foreach element $list {
        lappend res [apply $lambdaExpression $element]
    }
    return $res
}

proc filter {lambdaExpression list} {
    set res {}
    foreach element $list {
        if {[apply $lambdaExpression $element] == 1} {
            lappend res $element
        }
    }
    return $res
}

# Args are defined like {name comparator source version}

# Writes a sourceable script for using local packages
proc provide_autoloader {path} {
    set destination [file join $path "mug_autoloader.tcl"]
    set mug_path [file join $path mug_packages]

    file mkdir $mug_path

    set first {set ::auto_path [linsert $::auto_path 0 }
    set last {]}

    set file_id [open $destination "w"]
    puts $file_id $first$mug_path$last
    close $file_id
}

proc get_arch {} {
    set sys_os $::tcl_platform(os)
    set sys_machine $::tcl_platform(machine)

    if {$sys_os == "Darwin"} {
        set os "macosx"
    } elseif {$os == "Linux"} {
        set os "linux"
    } else {
        set os "unknown"
    }
    
    # TODO: Make this support non-x86 platforms
    if {$sys_machine == "x86_64"} {
        set machine "x86-64"
    } else {
        set machine "x86"
    } else {
        set machine "unknown"
    }
    return "$os $machine"
}

# Get a URL really simply
proc get_page {url} {
    set token [::http::geturl $url]
    set data [::http::data $token]
    ::http::cleanup $token          
    return $data
}

# From a Teapot URL, extract the meaningful data
proc extract_teapot_string {teapot_string} {
    set start [string first {[[TPM[[} $teapot_string]
    set end [string first {]]MPT]]} $teapot_string]
    return [string range $teapot_string [expr {$start + 7}] [expr {$end - 1}]]
}

proc get_teapot_info {url} {
    set data [get_page $url]
    return [extract_teapot_string $data]
}

proc match_version {available target} {

    if {$target == "any"} {
        return 1
    }

    set operator [lindex $target 0]
    set version [lindex $target 1]

    if {$operator == "=="} {
        return [expr {$version == $available}]
    } 

    set exploded_version [split $version "."]
    set exploded_available [split $available "."]

    # Approx equal - find something that matches the substring on the left
    if {$operator == "~"} {
        foreach version_part $exploded_version available_part $exploded_available {
            if {$version_part == {}} {
                return 1
            }
            if {$version_part != $available_part} {
                return 0
            }
        }
        return 1
    }

    if {$operator == ">="} {
        foreach version_part $exploded_version available_part $exploded_available {
            if {$version_part == {}} {
                return 1
            } elseif {$available_part < $version_part} {
                return 0
            } elseif {$available_part > $version_part} {
                return 1
            }
        }
        return 1
    }

    if {$operator == ">"} {
        foreach version_part $exploded_version available_part $exploded_available {
            if {$version_part == {}} {
                return 1
            } elseif {$available_part < $version_part} {
                return 0
            } elseif {$available_part > $version_part} {
                return 1
            }
        }
        return 0
    }

    if {$operator == "<="} {
        foreach version_part $exploded_version available_part $exploded_available {
            if {$version_part == {}} {
                return 1
            } elseif {$available_part > $version_part} {
                return 0
            } elseif {$available_part < $version_part} {
                return 1
            }
        }
        return 1
    }

    if {$operator == "<"} {
        foreach version_part $exploded_version available_part $exploded_available {
            if {$version_part == {}} {
                return 1
            } elseif {$available_part < $version_part} {
                return 0
            } elseif {$available_part > $version_part} {
                return 1
            }
        }
        return 0
    }

}

proc pick_newest {packages} {
    #FIXME: Make it do something
    return [lindex $packages 0]
}

proc match_platform {available target} {
    #FIXME: Make it split open our version tuple
    return [expr {$available == $target}]
}

proc parse_version_pattern {pattern} {
    if {$pattern == "any"} {
        return $pattern
    }

    set strlen [string length $pattern]

    if {[string first "==" $pattern] == 0 || [string first ">=" $pattern] == 0 || [string first "<=" $pattern] == 0} { 
        return "[string range $pattern 0 1] [string trim [string range $pattern 2 $strlen]]"
    } elseif {[string first ">" $pattern] == 0 || [string first "<" $pattern] == 0 || [string first "~" $pattern] == 0} {
        return "[string range $pattern 0 0] [string trim [string range $pattern 1 $strlen]]"
    } else {
        error "Invalid pattern $pattern"
    }
}

proc find_teapot_package {teapot_url package_name {version "any"} {platform "tcl"}} {
    # Find the package in our packages list
    set packages [get_teapot_info $teapot_url/package/list]

    set named_packages [filter {package_tuple {
        upvar 2 package_name package_name version version platform platform
        if {[lindex $package_tuple 1] == $package_name &&
            [match_version [lindex $package_tuple 2] $version] &&
            [match_platform [lindex $package_tuple 3] $platform]} {
            return 1
        }
    }} $packages]

    return [pick_newest $named_packages]
}

proc install {args} {
}

proc main {args} {
    #puts [match_version "3.1.4" [parse_version_pattern ">1"]]
    #provide_autoloader [pwd]
    #puts [find_teapot_package "http://teapot.activestate.com/" "base64" "2.4.2"]
}

#main $::argv
