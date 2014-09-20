Flightplan = require "flightplan"
{local, remote, slowpost} = require "./slowpost.flightplan"

# `SSH_PARAMS` provides address and access parameters for an individual destination
# machine. Used to define routes when `slowpost.flightplan` is constructed.
SSH_PARAMS = (host) ->
  host: host
  username: "core"
  agent: process.env.SSH_AUTH_SOCK


# Define a flightplan with routes to all destination machines.
slowpost.flightplan = (new Flightplan).briefing
  destinations:
    production: [{
      host: "p1.slow.example.org"
      username: "core"
      agent: process.env.SSH_AUTH_SOCK
    }]

# Define the default set of tasks.
slowpost.defineTasks()


  # # Remove docker containers. why?
  # slowpost.remote ["cleanup", "clean_docker_containers"], (remote) ->
  #   if containers = remote.exec("docker ps --all --quiet | grep 'Exited' | awk '{print $1}'").stdout
  #     remote.log "removing containers: #{JSON.stringify containers}"
  #     remote.exec "docker rm #{containers.join(' ')}"
  #
  # # Remove docker images that are ?
  # slowpost.remote ["cleanup", "clean_docker_images"], (remote) ->
  #   if images = remote.exec("docker images | grep '^<none>' | awk '{print $3}'").stdout.trim().split()
  #     remote.log "removing images: #{JSON.stringify images}"
  #     remote.exec "docker rmi #{images.join(' ')}"
  #

slowpost.Deploy::message = ->
  {hosts, destination} = slowpost.flightplan.target
  return """
    Advanced deploy to #{(h.host for h in hosts).join(" ")} at #{destination}.
    Repository #{slowpost.repo}
    Branch #{slowpost.branch}
    Commit #{slowpost.commit}
    #{if @completed then "Completed in #{(@completed - @started) / 1000} seconds" else "Incomplete!"}
  """
