{ ExampleView } = require '../lib/example-view'
{ ExampleModel, ExampleModelState, ExampleModelProperty } = require '../lib/example-view'
{ makeObservableArray } = require '../lib/example-view'
{ SymbolSet } = require '../lib/symbol-set'
{ LineSet } = require '../lib/line-set'
{ ValueMap } = require '../lib/value-analysis'
{ Range } = require 'atom'
$ = require 'jquery'
_ = require 'lodash'


makeEditor = -> atom.workspace.buildTextEditor()

editor = makeEditor()
editor.setText [
  "int i = 0;"
  "int j = i;"
  "i = j + 1;"
  "j = j + 1;"
  ].join '\n'
codeBuffer = editor.getBuffer()


describe "ExampleModel", ->

  observer =
    onPropertyChanged: (object, name, value) ->
      @object = object
      @propertyName = name
      @propertyValue = value

  it "notifies observers when lines changed", ->
    lineSet = new LineSet()
    exampleModel = new ExampleModel codeBuffer, lineSet, new SymbolSet(), new ValueMap()
    exampleModel.addObserver observer
    lineSet.getActiveLineNumbers().push 1
    (expect observer.propertyName).toBe ExampleModelProperty.ACTIVE_LINE_NUMBERS
    (expect observer.propertyValue).toEqual [1]

  it "notifies observers when the list of undefined symbols changes", ->
    symbols = new SymbolSet()
    exampleModel = new ExampleModel codeBuffer, new LineSet(), symbols, new ValueMap()
    exampleModel.addObserver observer
    symbols.addUndefinedUse { name: "sym", line: 1, start: 5, end: 6 }
    (expect observer.propertyName).toBe ExampleModelProperty.UNDEFINED_USES
    (expect observer.propertyValue).toEqual { name: "sym", line: 1, start: 5, end: 6 }


describe "ExampleView", ->

  it "shows text for the lines in the model's list", ->
    model = new ExampleModel codeBuffer, new LineSet([1, 2]), new SymbolSet(), new ValueMap()
    view = new ExampleView model, makeEditor(), codeBuffer
    exampleText = view.getTextEditor().getText()
    expect(exampleText.indexOf "int i = 0;").not.toBe -1
    expect(exampleText.indexOf "int j = i;").not.toBe -1
    expect(exampleText.indexOf "i = j + 1;").toBe -1
    expect(exampleText.indexOf "j = j + 1;").toBe -1

  it "updates text display when the list of lines changes", ->

    lineSet = new LineSet [1, 2]
    model = new ExampleModel codeBuffer, lineSet, new SymbolSet(), new ValueMap()
    view = new ExampleView model, makeEditor()

    # Remove first line from the list
    lineSet.getActiveLineNumbers().splice 0, 1

    # Add another line index to the list
    lineSet.getActiveLineNumbers().push 3

    exampleText = view.getTextEditor().getText()
    expect(exampleText.indexOf "int i = 0;").toBe -1
    expect(exampleText.indexOf "int j = i;").not.toBe -1
    expect(exampleText.indexOf "i = j + 1;").not.toBe -1
    expect(exampleText.indexOf "j = j + 1;").toBe -1

  it "focuses undefined symbols in PICK_UNDEFINED mode", ->

    symbolSet = new SymbolSet()

    model = new ExampleModel codeBuffer, new LineSet([3]), symbolSet, new ValueMap()
    view = new ExampleView model, makeEditor()
    model.setState ExampleModelState.PICK_UNDEFINED
    symbolSet.addUndefinedUse { name: "j", line: 3, start: 5, end: 6 }

    editor = view.getTextEditor()
    markers = editor.getMarkers()
    (expect markers.length).toBe 1

    # Note that the range that's marked is going to be different from the
    # original symbol position, as its position in the new editor will
    # be different from its position in the old code buffer, due to
    # pretty-printing and modifications to the code
    markerBufferRange = markers[0].getBufferRange()
    (expect markerBufferRange).toEqual new Range [4, 12], [4, 13]

    # As a sanity check, the text at this location should be the symbol name
    (expect editor.getTextInBufferRange(markerBufferRange)).toBe "j"

  describe "after marking up a symbol", ->

    symbolSet = new SymbolSet()
    model = new ExampleModel codeBuffer, new LineSet([3]), symbolSet, new ValueMap()
    view = new ExampleView model, makeEditor()
    model.setState ExampleModelState.PICK_UNDEFINED
    symbolSet.addUndefinedUse { name: "j", line: 3, start: 5, end: 6 }

    editor = view.getTextEditor()
    buttonDecorations = editor.getDecorations { class: 'undefined-use-button' }
    highlightDecorations = editor.getDecorations { class: 'undefined-use-highlight' }
    markers = editor.getMarkers()

    it "decorates the symbol", ->
      # Make sure that the decoration is associated with the marker created
      (expect buttonDecorations.length).toBe 1
      (expect highlightDecorations.length).toBe 1
      (expect buttonDecorations[0].getMarker()).toBe markers[0]
      (expect highlightDecorations[0].getMarker()).toBe markers[0]

    it "updates the target when the decoration is clicked", ->
      domElement = $ (buttonDecorations[0].getProperties()).item
      domElement.click()
      (expect model.getTarget()).toEqual \
        { name: "j", line: 3, start: 5, end: 6 }

  it "skips focusing on undefined symbols not in the range of chosen lines", ->

    # This time, the undefined use appears on a line that's not within view.
    # We shouldn't add any marks for the symbol.
    symbolSet = new SymbolSet()
    symbolSet.addUndefinedUse { name: "j", line: 3, start: 5, end: 6 }

    model = new ExampleModel codeBuffer, new LineSet([1]), symbolSet, new ValueMap()
    view = new ExampleView model, makeEditor()
    markers = view.getTextEditor().getMarkers()
    (expect markers.length).toBe 0

  it "skips focusing on undefined symbols if it's not in PICK_UNDEFINED mode", ->

    symbolSet = new SymbolSet()
    symbolSet.addUndefinedUse { name: "Line", line: 3, start: 5, end: 6 }
    model = new ExampleModel codeBuffer, new LineSet([3]), symbolSet, new ValueMap()
    view = new ExampleView model, makeEditor()

    # Only show markers when we're picking from undefined uses
    model.setState ExampleModelState.PICK_UNDEFINED
    (expect view.getTextEditor().getMarkers().length).toBe 1
    model.setState ExampleModelState.VIEW
    (expect view.getTextEditor().getMarkers().length).toBe 0

  describe "when the state is set to DEFINE", ->

    symbolSet = new SymbolSet()
    valueMap = new ValueMap()
    _.extend valueMap, {
      'Example.java':
        2: { i: '0' }
        3: { i: '0', j: '0' }
        4: { i: '1', j: '0' }
    }
    symbolSet.setDefinition { name: "j", line: 2, start: 5, end: 6 }
    model = new ExampleModel codeBuffer, new LineSet([3]), symbolSet, valueMap
    view = new ExampleView model, makeEditor()

    # By setting a target and setting the state to DEFINE, the view should
    # update by adding a new marker to the undefined use
    model.setTarget { file: "Example.java", name: "j", line: 3, start: 5, end: 6 }
    model.setState ExampleModelState.DEFINE

    it "adds a marker for defining the target", ->
      editor = view.getTextEditor()
      markers = editor.getMarkers()
      (expect markers.length).toBe 1
      markerBufferRange = markers[0].getBufferRange()
      (expect markerBufferRange).toEqual new Range [4, 12], [4, 13]

    describe "creates a new widget such that", ->

      editor = view.getTextEditor()
      decorations = editor.getDecorations { class: 'definition-widget' }
      decoration = decorations[0]
      markers = editor.getMarkers()

      it "corresponds to the new marker", ->
        (expect decorations.length).toBe 1
        (expect decoration.getMarker()).toBe markers[0]

      domElement = $ decoration.getProperties().item
      addCodeButton = domElement.find "#add-code-button"
      setValueButton = domElement.find "#set-value-button"

      it "shows suggestions when the mouse enters the definition button", ->
        (expect model.getLineSet().getSuggestedLineNumbers()).toEqual []
        addCodeButton.mouseover()
        (expect model.getLineSet().getSuggestedLineNumbers()).toEqual [2]

      it "hides suggestions when the mouse leaves the definition button", ->
        (expect model.getLineSet().getSuggestedLineNumbers()).toEqual [2]
        addCodeButton.mouseout()
        (expect model.getLineSet().getSuggestedLineNumbers()).toEqual []

      it "selects lines when the definition button is clicked", ->
        # To realistically simulate a user, we send a mouse-over event
        # before we send the click event
        addCodeButton.mouseover()
        addCodeButton.click()
        (expect 2 in model.getLineSet().getActiveLineNumbers()).toBe true
        (expect 3 in model.getLineSet().getActiveLineNumbers()).toBe true
        (expect model.getLineSet().getActiveLineNumbers().length).toBe 2
        (expect model.getLineSet().getSuggestedLineNumbers()).toEqual []

      # Refresh the markers: the earlier changes to the data refreshed the
      # code view, so the old marker handles are stale
      getTextInCurrentMarkerBufferRange = =>
        markers = editor.getMarkers()
        markerBufferRange = markers[0].getBufferRange()
        editor.getTextInBufferRange markerBufferRange

      it "shows values when the mouse enters the data button", ->
        (expect getTextInCurrentMarkerBufferRange()).toEqual 'j'
        setValueButton.mouseover()
        (expect getTextInCurrentMarkerBufferRange()).toEqual '0'

      it "restores values when the mouse leaves the data button", ->
        (expect getTextInCurrentMarkerBufferRange()).toEqual '0'
        setValueButton.mouseout()
        (expect getTextInCurrentMarkerBufferRange()).toEqual 'j'