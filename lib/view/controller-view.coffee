{ PACKAGE_PATH } = require "../config/paths"
$ = require 'jquery'


module.exports.ControllerView = class ControllerView extends $

  constructor: (controller, exampleEditor) ->
    @controller = controller
    @exampleEditor = exampleEditor

    element = $ "<div></div>"
      .addClass "controller"

    # Make a button for running the chosen agent
    @printButton = $ "<button></button>"
      .attr "id", "print-symbol-button"
      .attr "disabled", (exampleEditor.getSelectedText().length == 0)
      .append @_svgForIcon "double-quote-serif-left"
      .append "Print"
      .click =>
        symbolName = exampleEditor.getSelectedText()
        controller.addPrintedSymbol symbolName
      .appendTo element

    @undoButton = $ "<button></button>"
      .attr "id", "undo-button"
      .attr "disabled", (controller.getCommandStack().getHeight() == 0)
      .append @_svgForIcon "action-undo"
      .append "Undo"
      .click => controller.undo()
      .appendTo element

    # Enable the undo button based on whether there are commands on the stack
    controller.getCommandStack().addListener {
      onStackChanged: (stack) => @undoButton.attr "disabled", (stack.getHeight() == 0)
    }

    # Enable the print button based on whether a selection has been made
    exampleEditor.onDidChangeSelectionRange (event) =>
      newRange = event.newBufferRange
      @printButton.attr "disabled", (newRange.start.isEqual newRange.end)

    @.extend @, element

  _svgForIcon: (iconName )->
    use = $ "<use></use>"
      .attr "xlink:href", "#{PACKAGE_PATH}/styles/open-iconic.svg##{iconName}"
      .addClass "icon-#{iconName}"
    svg = $ "<svg></svg>"
      .addClass "icon"
      .attr "width", "100%"
      .attr "height", "100%"
      .attr "viewBox", "0 0 8 8"
      .append use
    # We return HTML instead of the object based on this recommended hack:
    # https://stackoverflow.com/questions/3642035/
    $ "<div></div>"
      .append svg
      .html()

  getNode: ->
    @[0]
