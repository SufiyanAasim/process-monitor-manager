#!/bin/bash

show_process_info() {
    echo -e "\nPID\tPPID\tCMD\t\t%MEM\t%CPU"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -15
}

show_process_tree() {
    echo -e "\nProcess Hierarchy (Tree View):"
    pstree -p
}

