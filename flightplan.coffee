# [Flightplan](https://github.com/pstadler/flightplan) executes command sequences on local and remote hosts.
Flightplan = require "flightplan"

# Prepare a `slowpost` instance that will accept a new `Flightplan`.
slowpost = require "./slowpost.flightplan"

# Construct a `slowpost.flightplan` with routes to all your destination machines.
# Routes are defined with `host`, `username` and `agent` parameters durring the flightplan briefing.
# Your SSH identities are loaded automatically when `agent` is assigned to your SSH authentication socket.
slowpost.flightplan = (new Flightplan).briefing
  destinations:
    "undefined": [{
      host: "slowpost.example.org"
      username: "core"
      agent: process.env.SSH_AUTH_SOCK
    }]

# The owner of this `miniLock ID` is permitted access to the host library.
slowpost.miniLock_ID = "PASTE_YOUR_MINILOCK_ID_HERE"

# `location` describes the culture and geography of the destination.
slowpost.location = "an undisclosed location"

# `hostname` defaults to the name of the first destination machine if left undefined.
slowpost.hostname = undefined

# `mail_address` defaults to `bonjour@hostname` if left undefined.
slowpost.mail_address = undefined

# Redefine `repo` to deploy a private fork of the source code.
slowpost.repo = "git://git@github.com:slowpost/slowpost.git"

# Define commands on the flightplan.
slowpost.defineCommands()
