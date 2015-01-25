p = (args...)-> console.log(args...)

min_by = (ary, f)->
  min = Infinity
  res = null
  for e in ary
    n = f(e) 
    if n < min
      min = n
      res = e
  res

class RNG
  constructor: (@size = 1000)->
    @ary = (Math.random() for i in [0...@size])
    @idx = 0

  random: ->
    @ary[@idx++ % @size]

  reset: ->
    @idx = 0

class Group
  constructor: (@x, @y, hsl)->
    @dots = []
    @color = "hsl(" + hsl + ",100%,50%)"

  centering: ->
    unless @dots.length is 0
      @x = d3.sum(@dots, (d)-> d.x) / @dots.length
      @y = d3.sum(@dots, (d)-> d.y) / @dots.length

class Dot
  constructor: (@x, @y)->
    @group = null

  cosineDistance: (a1, a2, b1, b2)->
    1 - (a1*b1+a2*b2) / (Math.sqrt(a1**2+a2**2)*Math.sqrt(b1**2+b2**2))

  tanimotoDistance: (a1, a2, b1, b2)->
    1 - (a1*b1+a2*b2) / (Math.sqrt(a1**2+a2**2)+Math.sqrt(b1**2+b2**2)-(a1*b1+a2*b2))

  euclideanDistance: (a1, a2, b1, b2)->
    (a1-b1)**2 + (a2-b2)**2

  manhattanDistance: (a1, a2, b1, b2)->
    Math.abs(a1-b1) + Math.abs(a2-b2)

  nearestGroup: (groups)->
    min_by groups, (g)=> @euclideanDistance(@x, @y, g.x, g.y)

class Kmeans
  constructor: (rand, N, K) ->
    @groups = (new Group(rand()..., i*360/K) for i in [0...K])
    @dots = (new Dot(rand()...) for i in [0...N])
    @flag = false

  step: ->
    if @flag
      @centering()
    else
      @grouping()
    @flag = not @flag

  centering: ->
    g.centering() for g in @groups

  grouping: ->
    g.dots = [] for g in @groups
    for d in @dots
      g = d.nearestGroup(@groups)
      g.dots.push d
      d.group = g

class Visualizer
  constructor: ->
    @Width = (d3.select("#kmeans")[0][0].offsetWidth - 20) * 1/1
    @Height = @Width * 9/16

    svg = d3.select("#kmeans svg")
    .attr("width", @Width)
    .attr("height", @Height)
    .style("padding", "10px")
    .style("background", "#223344")
    .style("cursor", "pointer")
    .style("-webkit-user-select", "none")
    .style("-khtml-user-select", "none")
    .style("-moz-user-select", "none")
    .style("-ms-user-select", "none")
    .style("user-select", "none")

    @lineg = svg.append("g")
    @circleg = svg.append("g")
    @pathg = svg.append("g")

    d3.selectAll("#kmeans button")
    .style("padding", ".5em .8em")

    d3.selectAll("#kmeans label")
    .style("display", "inline-block")
    .style("width", "15em")

    d3.select("#step").on "click", => @step()
    d3.select("#restart").on "click", => @restart()
    d3.select("#reset").on "click", => @reset()
    d3.select("#auto").on "click", => @auto()
    svg.on "click", =>
      d3.event.preventDefault()
      @step()

    @reset()

  reset: ->
    @rng = new RNG()
    @restart()

  restart: ->
    N = parseInt(d3.select("#NodeSize")[0][0].value, 10)
    K = parseInt(d3.select("#ClusterSize")[0][0].value, 10)
    @rng.reset()
    rand = => [@rng.random()*@Width, @rng.random()*@Height]
    @cluster = new Kmeans(rand, N, K)
    @clearAuto()
    @draw(0)

  step: ->
    @cluster.step()
    @draw(400)

  clearAuto: ->
    if @intervalId != null
      clearInterval(@intervalId)
      d3.select("#auto").text("オート")
    @intervalId = null
  
  auto: ->
    if @intervalId != null
      @clearAuto()
    else
      wait = parseInt(d3.select("#Wait")[0][0].value, 10)
      @intervalId = setInterval((=> @step()), wait)
      d3.select("#auto").text("ストップ")
    
  draw: (duration)->
    attrLines = (lines) ->
      lines.attr("x1", (d) -> d.x)
      .attr("y1", (d) -> d.y)
      .attr("x2", (d) -> d.group.x)
      .attr("y2", (d) -> d.group.y)
      .attr("stroke", (d) -> d.group.color)
      .attr("stroke-width", 0.7)

    attrCircles = (circles) ->
      circles.attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)
      .attr("r", 2)
      .attr("fill", (d) -> d.group?.color or "#ffffff")

    attrPaths = (paths) ->
      paths.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ") rotate(45)")
      .attr("d", d3.svg.symbol().type("cross"))
      .attr("fill", (d) -> d.color)
      .attr("stroke", "#ccddee")
      .attr("stroke-width", 2)

    drawParts = (type, typeg, attrMethod, data)->
      elems = typeg.selectAll(type).data(data)
      elems.enter().append(type)
      attrMethod elems.transition().duration(duration)
      elems.exit().remove()

    if @cluster.dots[0].group
      drawParts "line", @lineg, attrLines, @cluster.dots
    else
      @lineg.selectAll("line").remove()

    drawParts "circle", @circleg, attrCircles, @cluster.dots
    drawParts "path", @pathg, attrPaths, @cluster.groups

new Visualizer()
