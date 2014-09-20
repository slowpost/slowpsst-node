# [Flightplan](https://github.com/pstadler/flightplan) executes command sequences on local and remote hosts.
Flightplan = require "flightplan"

# Prepare a `slowpost` instance that will accept a `repo` and a `flightplan`.
slowpost = require "./slowpost.flightplan"

# `slowpost.repo` defines the location of the source code.
# Redefine it to use a fork.
slowpost.repo = "git://git@github.com:slowpost/slowpost.git"

# `slowpost.flightplan` contains routes to all your destination machines.
# Routes are defined with `host`, `username` and `agent` parameters durring the flightplan briefing.
# Your SSH identities are loaded automatically when `agent` is assigned to your SSH authentication socket.
slowpost.flightplan = (new Flightplan).briefing
  destinations:
    "undefined": [{
      host: "slowpost.example.org"
      username: "core"
      agent: process.env.SSH_AUTH_SOCK
    }]

# Define default set of commands.
slowpost.defineCommands()
