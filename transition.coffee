$j = jQuery

random = new Random


class Cube
  constructor: (@gridPos, position, size, color, @colorVarianz, opacity=1.0) ->
    #@color =  new THREE.MeshLambertMaterial({color:"rgba(255, 0, 23, 0.4)"})
    @color =  new THREE.MeshLambertMaterial({color: color.getHex(), \
                                             opacity: opacity, \
                                             transparent: true})

    @mesh = new THREE.Mesh(new THREE.CubeGeometry(size.x, size.y, size.z, 1,
      1, 1),@color)
    @mesh.position = position

  getPossibleColor: ->
    r = this.capVal(random.gauss @color.color.r, @colorVarianz.x)
    g = this.capVal(random.gauss @color.color.g, @colorVarianz.y)
    b = this.capVal(random.gauss @color.color.b, @colorVarianz.z)
    color = new THREE.Color
    color.setRGB r, g, b
    return color

  capVal: (val) ->
    val = Math.max(0, Math.min(1,val))
    return val

  adjustColorWeight: (µ, h, inputColor) ->
    inputColor = new THREE.Vector3(inputColor.r, inputColor.g, inputColor.b)
    ownColor = new THREE.Vector3(@color.color.r, @color.color.g, @color.color.b)
    inputColor.sub(ownColor)
    w = µ * h
    inputColor.multiplyScalar(w)
    ownColor.add(inputColor)
    @color.color.setRGB ownColor.x, ownColor.y, ownColor.z

class Grid
  constructor: (@gridSize, @size, colorFun) ->
    @mesh = new THREE.Object3D()
    @cubes = []

    colorStepX = 255 / (@gridSize.x-1)
    colorStepY = 255 / (@gridSize.y-1)
    colorStepZ = 255 / (@gridSize.z-1)

    colorVarianz = new THREE.Vector3(colorStepX/510, colorStepY/510, colorStepZ/510)

    stepX = @size.x / @gridSize.x
    stepY = @size.y / @gridSize.y
    stepZ = @size.z / @gridSize.z

    offsetX = -(stepX * gridSize.x/2)
    offsetY = -(stepY * gridSize.y/2)
    offsetZ = -(stepZ * gridSize.z/2)

    size = new THREE.Vector3(stepX*0.7, stepY*0.7, stepZ*0.7)

    for x in [0..@gridSize.x-1]
      @cubes.push []
      for y in [0..@gridSize.y-1]
        @cubes[x].push []
        for z in [0..@gridSize.z-1]
          pos = new THREE.Vector3(offsetX+stepX*x, offsetY+stepY*y,
            offsetZ + stepZ*z)
          color = new THREE.Color()
          rgb = colorFun(colorStepX, colorStepY, colorStepZ, x, y, z)
          color.setStyle(rgb)
          gridPos = new THREE.Vector3 x, y, z
          @cubes[x][y].push new Cube(gridPos, pos, size, color, colorVarianz, 0.8)
    for xvals in @cubes
      for yvals in xvals
        for cube in yvals
          @mesh.add cube.mesh

  highlightCube: (pos) ->
    this.setCubesOpacity(0.1)
    cube = @cubes[Math.floor pos.x][Math.floor pos.y][Math.floor pos.z].color.opacity = 1.0

  setCubesOpacity: (opacity) ->
    for xvals in @cubes
      for yvals in xvals
        for cube in yvals
          cube.color.opacity = opacity

  findBestMatch: (color) ->
    mindist = Number.MAX_VALUE
    candidate = undefined
    input = new THREE.Vector3(color.r, color.g, color.b)
    for xvals in @cubes
      for yvals in xvals
        for cube in yvals
          canColor = cube.color.color
          output = new THREE.Vector3(canColor.r, canColor.g, canColor.b)
          dist = input.distanceTo output
          if dist < mindist
            mindist = dist
            candidate = cube
    return candidate

  getNeighbours: (refCube, variance) ->
    variance = Math.floor(variance)
    xrange = [Math.max(0, refCube.gridPos.x - variance)..\
              Math.min(@gridSize.x-1, refCube.gridPos.x + variance)]

    yrange = [Math.max(0, refCube.gridPos.y - variance)..\
              Math.min(@gridSize.y-1, refCube.gridPos.y + variance)]
    neighbours = []

    denom = Math.max(2 * (variance*variance), 1)
    for x in xrange
      for y in yrange
        #We this will be the 2d grid
        cube = @cubes[x][y][0]
        distWeight = this.naivGauss refCube.gridPos, cube.gridPos, denom
        neighbours.push [distWeight, @cubes[x][y][0]]
    return neighbours

  naivGauss: (pos1, pos2, denom) ->
    distSquare = pos1.distanceToSquared(pos2)
    result = Math.exp(-(distSquare/denom))
    return result


class Scene
  constructor: (container, @grid, size, angle, @onFrame) ->
    aspect = size.x / size.y
    @renderer = new THREE.WebGLRenderer()
    @renderer.setSize size.x, size.y
    @camera = new THREE.PerspectiveCamera angle, aspect, 0.1, 1000
    @camera.position.z = 300
    @scene = new THREE.Scene()
    @scene.add(@grid.mesh)

    light = new THREE.PointLight(0xFFFFFFFF)
    light.position.x = 10
    light.position.y = 50
    light.position.z = 130
    @scene.add(light)

    container.append @renderer.domElement
    this.render()

  render: ->
    requestAnimationFrame(=> this.render())
    @renderer.render(@scene, @camera)
    if @onFrame
      @onFrame()

class Som
  constructor: (@inputGrid, @outputGrid) ->
    @step = 0
    @maxStep = 300

  train: () ->
    if @step < @maxStep
      setTimeout((=>this.train()), 150)
    this.trainStep(125, 100)

  getVariance: ->
    part = @outputGrid.gridSize.x/4
    m = -part/@maxStep
    return m*@step + part

  selectInputCube: ->
    inputCube = this._getRandomInput()
    @inputGrid.highlightCube(inputCube.gridPos)
    return inputCube

  selectBestOutputCube: (inputCube) ->
    bestMatch = @outputGrid.findBestMatch(inputCube.color.color)
    @outputGrid.highlightCube(bestMatch.gridPos)
    return bestMatch

  resetOpacities: ->
    @outputGrid.setCubesOpacity 1.0
    @inputGrid.setCubesOpacity 1.0

  getNeighbours: (bestMatch) ->
    variance = this.getVariance()
    return @outputGrid.getNeighbours bestMatch, variance

  moveCubes: (neighbours, time) ->
    for [weight, cube] in neighbours
      resetFun = (theCube, oldPos) ->
        setTimeout((->
          theCube.mesh.position = oldPos ), time)
      resetFun(cube, cube.mesh.position.clone())
      vec = new THREE.Vector3(0, 0, weight*30)
      cube.mesh.position.add vec

  weightCubes: (bestMatch, neighbours, time) ->
    µ = (Math.exp((-1/500)*@step)-0.4)
    for [weight, cube] in neighbours
      setColorFun = (theCube, color) ->
        setTimeout((->
          theCube.adjustColorWeight µ, weight, color), time)
      setColorFun(cube, bestMatch.color.color)
 
  trainStep: (time1=1000, time2=500) ->
    inputCube = this.selectInputCube()
    bestMatch = @outputGrid.findBestMatch(inputCube.color.color)
    neighbours = this.getNeighbours(bestMatch)
    this.moveCubes(neighbours, time1)
    this.weightCubes(bestMatch, neighbours, time2)
    @step += 1

  _getRandomInput: ->
    x = random.randrange @inputGrid.gridSize.x
    y = random.randrange @inputGrid.gridSize.y
    z = random.randrange @inputGrid.gridSize.z
    return @inputGrid.cubes[x][y][z]


#$j ->
#
#  size = new THREE.Vector2 400, 400
#
#  sortedColor = (colorStepX, colorStepY, colorStepZ, x, y, z) ->
#    return "rgb(#{Math.floor(colorStepX*x)},#{Math.floor(colorStepY*y)},#{Math.floor(colorStepZ*z)})"
#
#  inputGrid = new Grid(new THREE.Vector3(4, 4, 4), new THREE.Vector3(90, 90, 90),
#    sortedColor)
#  scene = new Scene $j('#inputSpace'), inputGrid, size, 45
#
#  randomColor = (colorStepX, colorStepY, colorStepZ, x, y, z) ->
#    r = random.randint(0, 255)
#    g = random.randint(0, 255)
#    b = random.randint(0, 255)
#    return "rgb(#{r},#{g},#{b})"
#  outputGrid = new Grid(new THREE.Vector3(32, 32, 1), new THREE.Vector3(190, 190, 10),
#    randomColor)
#  outputGrid.mesh.rotation.setX(-0.8)
#  scene = new Scene $j('#outputSpace'), outputGrid, size, 45
#
#  som = new Som inputGrid, outputGrid
