{exec} = require 'child_process'
fs = require 'fs'

lastChange = {}

scripts = ['transition.coffee', 'random-js/random.coffee']
styles  = ['cube.less']

compileCoffee = (file) ->
  exec "coffee -c #{file}", (err, stdout, stderr) ->
    return console.error(err) if err
    console.log "Compiled #{file}"

compileLess = (file) ->
  exec "lessc #{file} #{file.replace('.less', '.css')}",
    (err, stdout, stderr) ->
      return console.error err if err
      console.log "Compiled #{file}"

watchFile = (file, fn) ->
  try
    fs.watch file, (event, filename) ->
      return if event isnt 'change'
      # ignore repeated event misfires
      fn file if Date.now() - lastChange[file] > 1000
      lastChange[file] = Date.now()
  catch e
    console.log "Error watching #{file}"

watchFiles = (files, fn) ->
  for file in files
    lastChange[file] = 0
    watchFile file, fn
    console.log "Watching #{file}"

task 'build', 'Compile *.coffee and *.less', ->
  compileCoffee(f) for f in scripts
  compileLess(f) for f in styles

task 'watch', 'Compile + watch *.coffee and *.less', ->
  watchFiles scripts, compileCoffee
  watchFiles styles, compileLess

task 'watch:js', 'Compile + watch *.coffee only', ->
  watchFiles scripts, compileCoffee

task 'watch:css', 'Compile + watch *.less only', ->
  watchFiles styles, compileLess
