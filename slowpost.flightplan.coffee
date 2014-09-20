# Exports a `slowpost` instance that should a `flightplan`, `repo` and `miniLock ID` in your `flightplan.coffee` script.
slowpost = module.exports =
  "flightplan": undefined
  "repo": undefined
  "location": undefined
  "hostname": undefined
  "miniLock ID": undefined
  "email address": undefined

# Call `slowpost.defineCommands()` after your `flightplan.briefing` is complete to define the default set of slowpost commands.
slowpost.defineCommands = ->
  throw "Can’t define slowpost commands without flightplan" if slowpost["flightplan"] is undefined
  throw "Can’t define slowpost commands without repo" if slowpost["repo"] is undefined
  slowpost["location"] ?= slowpost.flightplan.target.destination
  slowpost["hostname"] ?= slowpost.flightplan.target.hosts[0].host
  throw "Can’t define slowpost commands without miniLock ID" if slowpost["miniLock ID"] is undefined
  slowpost["email address"] ?= "bonjour@#{slowpost.host()}"

  Authority = require "authority"
  NaCl = require "tweetnacl"
  URL = require "url"
  {readFileSync, writeFileSync, existsSync, readdirSync} = require "fs"

  # # Command Line Switches
  "<•>"

  # ## <tt>\--branch branch-name</tt>
  # `slowpost.branch` is defined on the command line at the beginning of `setup`, `build` and `deploy` commands.
  # Defaults to the <code>master</code> branch when it is left undefined.
  slowpost.local ["build", "deploy"], (local) ->
    if "--branch" in process.argv
      slowpost.branch = process.argv[process.argv.indexOf("--branch")+1]
    else
      slowpost.branch = "master"
    local.log "slowpost.branch is #{slowpost.branch}"

  # ## <tt>\--commit commit-hash</tt>
  # `slowpost.commit` is also defined for `setup`, `build` and `deploy` commands.
  # Default is the last commit in the selected branch of `slowpost.repo`.
  slowpost.local ["build", "deploy"], (local) ->
    slowpost.commit = process.argv[3]
    if slowpost.commit is undefined
      {stdout} = local.exec("git ls-remote #{slowpost.repo} #{slowpost.branch}", silent:yes)
      slowpost.commit = stdout.split("\t")[0]
    local.log "slowpost.commit is #{slowpost.commit}"

  # # Slowpost Flightplan Commands
  "<•>"

  # ## <tt>fly connect:destination</tt>
  # Test your connection to the destination.
  slowpost.remote ["connect"], (remote) ->
    remote.exec "hostname"
    remote.exec "cat /etc/motd"

  # ## <tt>fly inspect:destination</tt>
  # Inspect local and remote hosts.
  slowpost.local ["inspect"], (local) ->
    local.log "slowpost.flightplan.target.task:", slowpost.flightplan.target.task
    local.log "slowpost.flightplan.target.destination:", slowpost.flightplan.target.destination
    local.log "slowpost.flightplan.target.hosts:", JSON.stringify slowpost.flightplan.target.hosts
    local.log "slowpost.host:", slowpost.host()
    local.log "slowpost.repo:", slowpost.repo
  slowpost.remote ["inspect"], (remote) ->
    remote.exec "id"
    remote.exec "docker images"
    remote.exec "docker ps --all"
    remote.exec "docker info"

  # ## <tt>fly status:destination</tt>
  # ## <tt>fly destination</tt>
  # Get slowpost status.
  slowpost.local ["status", "default"], (local) ->
    local.log "host:", slowpost.host()
    local.log "repo:", slowpost.repo
  slowpost.remote ["status", "default"], (remote) ->
    remote.exec "systemctl status slowpost"
    remote.exec "docker ps --all"
    remote.exec "docker images"

  # ## <tt>fly start:destination</tt>
  # Start slowpost and show status, wait ten seconds, and then show status again.
  slowpost.remote "start", (remote) ->
    remote.sudo "systemctl start slowpost"
    remote.exec "systemctl status slowpost"
    remote.sudo "sleep 10"
    remote.exec "systemctl status slowpost"

  # ## <tt>fly stop:destination</tt>
  # Stop slowpost and show status.
  slowpost.remote "stop", (remote) ->
    remote.sudo "systemctl stop slowpost"
    remote.exec "systemctl status slowpost", failsafe: true

  # ## <tt>fly deploy:destination</tt>
  # ## <tt>fly deploy:destination \--commit commit-hash</tt>
  # ## <tt>fly deploy:destination \--branch branch-name</tt>
  # Update the slowpost source code and unit file at destination, restart service and record one commit in the deploy history.
  # If the deploy branch does not exist it is created automatically.
  slowpost.local "deploy", (local) ->
    branches = (line.replace("*", "").trim() for line in local.exec("git branch").stdout.trim().split("\n"))
    if "deploy" in branches
      local.log "deploy branch is ready."
    else
      local.log "Creating deploy branch"
      local.exec "git branch --create deploy"
    local.exec "git checkout deploy"
  # Every deploy command creates a `Dockerfile` in the `slowpost_image` folder.
  # It is transferred to the destination along with a few other `slowpost_image` files and the `slowpost.service` file.
  # Secrets in the Dockerfile are removed when the transfer is complete so that they are not included in the `deploy` history.
  slowpost.local "deploy", (local) ->
    slowpost.writeDockerfile()
    local.log "Wrote slowpost_image/Dockerfile to local filesystem."
    transfers = ["slowpost.service"].concat(slowpost.imageFiles())
    local.log "Transfering slowpost.service and slowpost_image files:", JSON.stringify(transfers)
    local.transfer transfers, "/home/core"
    slowpost.removeDockerfileSecrets()
    local.log "Removed secrets in local copy of slowpost_image/Dockerfile."
  # A record of the deploy is committed to history before remote connections are established.
  slowpost.local "deploy", (local) ->
    slowpost.deploy = new slowpost.Deploy
    local.exec "git add --all"
    local.exec "git commit --message '#{slowpost.deploy.message()}'", silent: yes
  # A `docker` image named `slowpost_image` is built at the destination from the files in `/home/core/slowpost_image`.
  # It is tagged with `slowpost_image:commit-hash` and `slowpost_image:deploy` to distinguish it from other images.
  slowpost.remote "deploy", (remote) ->
    remote.log "Building /home/core/slowpost_image"
    remote.exec "docker build --tag slowpost_image /home/core/slowpost_image"
    remote.exec "docker tag slowpost_image slowpost_image:#{slowpost.commit.slice(0, 16)}"
    remote.exec "docker tag slowpost_image slowpost_image:deploy"
    remote.exec "rm -r /home/core/slowpost_image"
    remote.log "Finished build and erased /home/core/slowpost_image"
    # When the `slowpost_image` is ready, the service is stopped, relinked and then restarted.
    # The service status is displayed immediately after restart.
    remote.sudo "systemctl stop slowpost"
    remote.sudo "systemctl link /home/core/slowpost.service"
    remote.sudo "systemctl start slowpost"
    remote.exec "systemctl status slowpost"
  # The deploy history is updated after a successfull restart.
  slowpost.local "deploy", (local) ->
    local.exec "git commit --amend --message '#{slowpost.deploy.complete().message()}'", silent: yes
  # Service status is displayed a second time after a 10 second delay to give the system a moment to get itself going.
  slowpost.remote "deploy", (remote) ->
    remote.exec "docker ps"
    remote.log "Checking status in 10 seconds..."
    remote.exec "sleep 10"
    remote.exec "systemctl status slowpost"

  # `Deploy` instances provide pre-deploy and post-deploy commit messages.
  class slowpost.Deploy
    constructor: ->
      @started = Date.now()

    complete: ->
      @completed = Date.now()
      return this

    message: ->
      {hosts, destination} = slowpost.flightplan.target
      lines = [
        "Deploy to #{(h.host for h in hosts).join(" ")} (#{destination})"
        "Commit #{slowpost.commit}"
        if @completed then "Completed in #{(@completed - @started) / 1000} seconds" else "Incomplete"
      ]
      "\n" + lines.join("\n") + "\n"


  # ## <tt>fly build:destination</tt>
  # ## <tt>fly build:destination \--commit commit-hash</tt>
  # ## <tt>fly build:destination \--branch branch-name</tt>
  #
  # Build a slowpost image at the destination.
  #
  # Unlike <tt>fly deploy</tt> this does not remove secrets in the local Dockerfile.
  #
  # Has no effect on slowpost service.
  slowpost.local "build", (local) ->
    slowpost.writeDockerfile()
    local.log "Wrote slowpost_image/Dockerfile to local filesystem."
    local.log "Transfering slowpost_image files:", JSON.stringify(slowpost.imageFiles())
    local.transfer slowpost.imageFiles(), "/home/core"
  slowpost.remote "build", (remote) ->
    remote.log "Building /home/core/slowpost_image"
    remote.exec "docker build --tag slowpost_image /home/core/slowpost_image"
    remote.exec "docker tag slowpost_image slowpost_image:#{slowpost.commit.slice(0, 16)}"
    remote.exec "docker tag slowpost_image slowpost_image:build"
    remote.exec "docker images"

  # ## <tt>fly setup:destination</tt>
  # ## <tt>fly setup:destination --commit commit-hash</tt>
  # ## <tt>fly setup:destination --branch branch-name</tt>
  #
  # Adds files to root/.ssh and slowpost/config and establishes /slowpost/storage.
  # It is safe to run setup over and over because it will skip unnessesary steps automatically.
  #
  # Make SSH keys.
  # Make SSH known hosts.
  slowpost.local ["setup", "make_ssh_keys_for_web_machine"], (local) ->
    pathToSecretKey = "slowpost_image/ssh.id.rsa.secret.key"
    pathToPublicKey = "slowpost_image/ssh.id.rsa.public.key"
    unless existsSync(pathToSecretKey)
      local.log "Generating SSH key pair in slowpost_image folder"
      local.exec "ssh-keygen -N '' -C '' -t rsa -b 4096 -f #{pathToSecretKey}"
      local.exec "mv #{pathToSecretKey}.pub #{pathToPublicKey}"
    else
      local.log "#{pathToSecretKey} is ready."
      local.log "#{pathToPublicKey} is ready."

  slowpost.local ["setup", "make_ssh_known_hosts_for_web_machine"], (local) ->
    pathToKnownHosts = "slowpost_image/ssh.known_hosts"
    unless existsSync pathToKnownHosts
      local.log "Generating SSH known hosts file in slowpost_image folder"
      local.exec "ssh-keyscan #{URL.parse("git://"+slowpost.repo).hostname} > #{pathToKnownHosts}"
    else
      local.log "#{pathToKnownHosts} is ready."

  # Make HTTPS session secret and signature.
  slowpost.local ["setup", "make_web_session_secret_and_signature"], (local) ->
    pathToSessionSecret = "slowpost_image/#{slowpost.host()}.session.secret"
    pathToSessionSignature = "slowpost_image/#{slowpost.host()}.session.signature"
    unless existsSync pathToSessionSecret
      local.log "Generating session secret for HTTPS service"
      sessionSecretKey = NaCl.randomBytes(64)
      encodedSessionSecret = NaCl.util.encodeBase64 sessionSecretKey
      sessionSignature = NaCl.sign NaCl.util.decodeUTF8(slowpost.host()), sessionSecretKey
      encodedSessionSignature = NaCl.util.encodeBase64 sessionSignature
      writeFileSync pathToSessionSecret, encodedSessionSecret, "utf-8"
      writeFileSync pathToSessionSignature, encodedSessionSignature, "utf-8"
      local.log "encoded session secret:", encodedSessionSecret
      local.log "encoded session signature:", encodedSessionSignature
    if existsSync pathToSessionSecret
      local.log "#{pathToSessionSecret} is ready."
    if existsSync pathToSessionSignature
      local.log "#{pathToSessionSignature} is ready."

  # Make HTTPS certificate and secret key.
  slowpost.local ["setup", "make_https_secret_key"], (local) ->
    pathToSecretKey   = "slowpost_image/#{slowpost.host()}.secret.key"
    pathToCertificate = "slowpost_image/#{slowpost.host()}.crt"
    # Make secret key.
    unless existsSync pathToSecretKey
      local.log "Generating secret key for HTTPS service"
      local.exec "openssl genrsa -out #{pathToSecretKey} 2048"
    if existsSync pathToSecretKey
      local.log "#{pathToSecretKey} is ready."
    # Make certificate.
    unless existsSync pathToCertificate
      subject =
        "organization":      "Slowpost Mail Exchange"
        "common_name":       slowpost.host()
        "email_address":     "bonjour@#{slowpost.host()}"
      subjectKey = readFileSync(pathToSecretKey)
      local.log "Generating X.509 certificate for HTTPS service:", JSON.stringify(subject)
      local.waitFor (certificateWrittenToFile) ->
        Authority.createCertificate
          "subject": subject
          "subject_key": subjectKey
          "started_at": (new Date).toJSON()
          "expires_at": "2080-01-01T00:00:01.000Z"
          "callback": (error, certificate) ->
            if error then throw error
            local.log "#{pathToCertificate} serial number is", certificate.serialNumber
            local.log "#{pathToCertificate} fingerprint is", certificate.fingerprint
            writeFileSync pathToCertificate, certificate.pem
            certificateWrittenToFile()
    if existsSync pathToCertificate
      local.log "#{pathToCertificate} is ready."

  # Establish `/slowpost/storage` on the CoreOS host.
  # TODO: Convert to systemd unit.
  slowpost.remote ["setup", "make_storage_volume"], (remote) ->
    storageExists = remote.exec("ls /slowpost/storage", {failsafe:yes}).code is 0
    unless storageExists
      remote.log "Making /slowpost/storage folder..."
      remote.sudo "mkdir -p /slowpost/storage"
      remote.sudo "chown root:root /slowpost"
      remote.sudo "chown -R core:docker /slowpost/storage"
      remote.sudo "chmod -R u=rwx,g=rwx,o-rwx /slowpost/storage"
      storageExists = yes
    if storageExists
      remote.log "/slowpost/storage is ready."

# `slowpost` provides `local` and `remote` methods to help you define your own commands.
slowpost.local = -> slowpost.flightplan.local.apply(slowpost.flightplan, arguments)
slowpost.remote = -> slowpost.flightplan.remote.apply(slowpost.flightplan, arguments)

# `slowpost.host()` is the public hostname of all machines at the target destination.
# It appears in `Common Name` and `Email Address` fields of your X.509 certificate and it defines the filenames of your certificate, secret key and session.json files.
slowpost.host = ->
  host = slowpost.flightplan.target.hosts[0].host
  if slowpost.flightplan.target.hosts.length is 1
    host
  else
    host.replace("p1.", "")


# `slowpost.imageFiles()` are the files in the `slowpost_image` folder that are transfered to destination machines durring a `build` or `deploy` command.
# Filenames are prefixed with `slowpost_image` for `local.transfer(...)` to `/home/core`.
slowpost.imageFiles = -> [
  "slowpost_image/Dockerfile"
  "slowpost_image/pacman.mirrorlist"
  "slowpost_image/ssh.id.rsa.public.key"
  "slowpost_image/ssh.id.rsa.secret.key"
  "slowpost_image/ssh.known_hosts"
  "slowpost_image/#{slowpost.host()}.crt"
  "slowpost_image/#{slowpost.host()}.secret.key"
]

# Removes secrets in the local Dockerfile so they don’t appear in the deploy history.
slowpost.removeDockerfileSecrets = ->
  {readFileSync, writeFileSync} = require "fs"
  dockerfile = readFileSync "slowpost_image/Dockerfile", "utf-8"
  dockerfile = dockerfile.replace readFileSync("slowpost_image/#{slowpost.host()}.session.secret"), "--secret--"
  writeFileSync "slowpost_image/Dockerfile", dockerfile, "utf-8"

# Writes a Dockerfile to the local file system.
# Replaces placeholders defined in the Dockerfile.template.
slowpost.writeDockerfile = ->
  {readFileSync, writeFileSync} = require "fs"
  dockerfile = readFileSync "slowpost_image/Dockerfile.template", "utf-8"
  dockerfile = dockerfile.replace /SLOWPOST_LOCATION/g, slowpost.location or slowpost.flightplan.target.destination
  dockerfile = dockerfile.replace /SLOWPOST_HOST/g, slowpost.host()
  dockerfile = dockerfile.replace /SLOWPOST_MINILOCK_ID/g, "FAKE MINILOCK ID FOR PRODUCTION"
  dockerfile = dockerfile.replace /SLOWPOST_SESSION_SIGNATURE/g, readFileSync("slowpost_image/#{slowpost.host()}.session.signature")
  dockerfile = dockerfile.replace /SLOWPOST_SESSION_SECRET/g, readFileSync("slowpost_image/#{slowpost.host()}.session.secret")
  dockerfile = dockerfile.replace /SLOWPOST_REPO/g, slowpost.repo
  dockerfile = dockerfile.replace /SLOWPOST_COMMIT/g, slowpost.commit
  dockerfile = dockerfile.replace /SLOWPOST_BRANCH/g, slowpost.branch
  dockerfile = dockerfile.replace /COMMENT/, "This Dockerfile was generated by #{slowpost.flightplan.target.task} task on #{(new Date).toJSON()}"
  writeFileSync "slowpost_image/Dockerfile", dockerfile, "utf-8"
