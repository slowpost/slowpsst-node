{series} = require "async"
{exec} = require "child_process"
{readdirSync, readFileSync, writeFileSync} = require "fs"

task "docs", "Build and publish docs", (options) ->
  console.info "docs"

task "docs:build", "Build docs", (options) ->
  sourceFiles = "*.coffee *.service slowpost_image/Dockerfile.template"
  exec "docco --languages docs/docco.languages.json #{sourceFiles} --output docs/docco", (error, stdout, stderr) ->
    console.info stdout.trim() if stdout
    throw stderr.trim() if stderr
    indexHTML = readFileSync("docs/index.html.template", "utf-8")
    indexHTML = indexHTML.replace("<slowpost.service>", postProcessDoccoHTML("slowpost.html"))
    indexHTML = indexHTML.replace("<Dockerfile>", postProcessDoccoHTML("Dockerfile.html"))
    indexHTML = indexHTML.replace("<flightplan.coffee>", postProcessDoccoHTML("flightplan.html"))
    indexHTML = indexHTML.replace("<slowpost.flightplan.coffee>", postProcessDoccoHTML("slowpost.flightplan.html"))
    writeFileSync "docs/index.html", indexHTML, "utf-8"
    console.info "Rendered docs/index.html.template and wrote docs/index.html"

postProcessDoccoHTML = (file) ->
  html = readFileSync("docs/docco/" + file, "utf-8")
  html = html.replace("<!DOCTYPE html>", "")
  html = html.replace("<html>", "<div>").replace("</html>", "</div>")
  html = html.replace("<head>", "").replace("</head>", "")
  html = html.replace("<title>", '<h1 class="filename">').replace("</title>", "</h1>")
  html = html.replace('<meta http-equiv="content-type" content="text/html; charset=UTF-8">', "")
  html = html.replace('<meta name="viewport" content="width=device-width, target-densitydpi=160dpi, initial-scale=1.0; maximum-scale=1.0; user-scalable=0;">', "")
  html = html.replace('<link rel="stylesheet" media="all" href="stylesheet.css" />', "")
  html = html.replace("<body>", "").replace("</body>", "")
  html = html.replace('<div id="container">', '<div class="file">')
  html = html.replace('<li id="title">', '<li class="title" hidden>')
  return html

task "docs:commit", "Commit docs to gh-pages", (options) ->
  series [
    (f) -> exec "cake docs", f
    (f) -> exec "git checkout gh-pages", f
    (f) -> exec "cp docs/*.css .", f
    (f) -> exec "cp docs/*.html .", f
    (f) -> exec "git add --all", f
    (f) -> exec "git commit -m 'docs'", (error, stdout, stderr) ->
      console.info(stdout)
      console.error(stderr)
      f()
  ], (error, stdout, stderr) ->
    if error is undefined
      exec "git checkout master", (error, stdout, stderr) ->
        console.info(stdout)
        console.error(stderr)
        throw error if error
    else
      console.info(stdout)
      console.error(stderr)
      throw error if error

task "docs:push", "Push gh-pages to origin", (options) ->
  exec "git push origin gh-pages", (error, stdout, stderr) ->
    console.info(stdout)
    console.error(stderr)
    throw error if error
