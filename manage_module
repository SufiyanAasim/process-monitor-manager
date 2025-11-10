#!/bin/bash

kill_process() {
    read -p "Enter PID to kill: " pid
    kill "$pid" && echo "Process $pid terminated." || echo "Failed to kill process $pid"
}

suspend_process() {
    read -p "Enter PID to suspend: " pid
    kill -STOP "$pid" && echo "Process $pid suspended." || echo "Failed to suspend process $pid"
}

resume_process() {
    read -p "Enter PID to resume: " pid
    kill -CONT "$pid" && echo "Process $pid resumed." || echo "Failed to resume process $pid"
}
